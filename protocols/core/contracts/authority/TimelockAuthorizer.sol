//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@almight/modules/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "@almight/modules/openzeppelin-contracts/contracts/utils/math/Math.sol";
import "@almight/contract-utils/contracts/authorizers/AccessAuthorizer.sol";
import "@almight/modules/openzeppelin-contracts/contracts/utils/Address.sol";
import "@almight/contract-interfaces/contracts/core/ITimelockAuthorizer.sol";

import "./TimelockExecutor.sol";

contract TimelockAuthorizer is ReentrancyGuard, ITimelockAuthorizer, AccessAuthorizer {

    // We institute a maximum delay to ensure that actions cannot be accidentally/maliciously disabled through setting
    // an arbitrarily long delay.
    uint256 public constant MAX_DELAY = 2 * (365 days);
    // We need a minimum delay period to ensure that all delay changes may be properly scrutinised.
    uint256 public constant MINIMUM_CHANGE_DELAY_EXECUTION_DELAY = 5 days;    
    



    // solhint-disable-next-line var-name-mixedcase
    bytes32 public immutable SCHEDULE_DELAY_ACTION_ID;

    address public root;
    address public pendingRoot;
    uint256 public rootTransferDelay;
    address public executor;

    /// @notice Some actions which needs to be executed immediately such as `pause`
    /// Only the root can utilize this feature.
    mapping(bytes32 => bool) public isDelayExemptedActionId;

    mapping(bytes32 => uint256) private _delaysPerActionId;

    // scheduled execution id => account => is executor
    mapping(uint256 => mapping(address => bool)) public isExecutor;

    ScheduledExecution[] private _scheduledExecutions;


    modifier onlyExecutor() {
        require(msg.sender == executor, "CAN_ONLY_BE_SCHEDULED");
        _;
    }

    
    constructor(
        address admin,
        address nextRoot,
        uint256 rootTransferDelay_

    ) AccessAuthorizer() {
        _setRoot(admin);
        // By setting `nextRoot` as the pending root, it can immediately call `claimRoot` and replace `initialRoot`,
        // skipping the root transfer delay for the very first root transfer. This is very useful in schemes where a
        // migrator contract is the initial root and performs some initial setup, and then needs to transfer this
        // permission to some other account.
        _setPendingRoot(nextRoot);
        
        executor = address(new TimelockExecutor());
        rootTransferDelay = rootTransferDelay_;

        SCHEDULE_DELAY_ACTION_ID = getActionId(ITimelockAuthorizer.scheduleDelayChange.selector);

        // Add super powers to admin for 3 years
        uint32 deadline = 3 * (365 days);
        _grantPermission(GENERAL_REVOKE_ACTION_ID, admin, EVERYWHERE, deadline);
        _grantPermission(GENERAL_GRANT_ACTION_ID, admin, EVERYWHERE, deadline);
    }

    function _setRoot(address root_) internal {
        root = root_;
        emit RootSet(root);
    }

    function _setPendingRoot(address root_) internal {
        pendingRoot = root_;
        emit PendingRootSet(pendingRoot);
    }


    function isRoot(address sender) public view returns(bool) {
        return root == sender;
    }

     /**
     * @notice Returns the action ID for scheduling setting a new delay for action `actionId`.
     */
    function getScheduleDelayActionId(bytes32 actionId) 
        public view returns(bytes32) {
            return getExtendedActionId(SCHEDULE_DELAY_ACTION_ID, actionId);
    }

    /**
     * @notice Returns the execution delay for action `actionId`.
     */
    function getActionIdDelay(bytes32 actionId) external view returns (uint256) {
        return _delaysPerActionId[actionId];
    }

     /**
     * @notice Returns the scheduled execution `scheduledExecutionId`.
     */
    function getScheduledExecution(uint256 scheduledExecutionId) external view returns (ScheduledExecution memory) {
        return _scheduledExecutions[scheduledExecutionId];
    }

    /**
     * @notice Returns true if execution `scheduledExecutionId` can be executed.
     * Only true if it is not already executed or cancelled, and if the execution delay has passed.
     */
    function canExecute(uint256 scheduledExecutionId) external view returns (bool) {
        require(scheduledExecutionId < _scheduledExecutions.length, "ACTION_DOES_NOT_EXIST");
        ScheduledExecution storage scheduledExecution = _scheduledExecutions[scheduledExecutionId];
        return
            !scheduledExecution.executed &&
            !scheduledExecution.cancelled &&
            block.timestamp >= scheduledExecution.executableAt;
        // solhint-disable-previous-line not-rely-on-time
    }


    /**
     * @notice Schedules an execution to change the root address to `newRoot`.
     */
    function scheduleRootChange(address newRoot, address[] memory executors)
        external
        returns (uint256 scheduledExecutionId)
    {
        require(isRoot(msg.sender), "SENDER_IS_NOT_ROOT");
        bytes32 actionId = getActionId(this.setPendingRoot.selector);
        bytes memory data = abi.encodeWithSelector(this.setPendingRoot.selector, newRoot);
        return _scheduleWithDelay(actionId, address(this), data, rootTransferDelay, executors);
    }

    /**
     * @notice Sets the pending root address to `pendingRoot`.
     * @dev This function can never be called directly - it is only ever called as part of a scheduled execution by
     * the TimelockExecutor after after calling `scheduleRootChange`.
     *
     * Once set as the pending root, `pendingRoot` may then call `claimRoot` to become the new root.
     */
    function setPendingRoot(address pendingRoot_) external onlyExecutor {
        _setPendingRoot(pendingRoot_);
    }


    /**
     * @notice Transfers root powers from the current to the pending root address.
     * @dev This function prevents accidentally transferring root to an invalid address.
     * To become root, the pending root must call this function to ensure that it's able to interact with this contract.
     */
    function claimRoot() external {
        address currentRoot = root;
        address pendingRoot_ = pendingRoot;
        require(msg.sender == pendingRoot, "SENDER_IS_NOT_PENDING_ROOT");

        // Grant powers to new root to grant or revoke any permission over any contract.
        _grantPermission(GENERAL_GRANT_ACTION_ID, pendingRoot, EVERYWHERE);
        _grantPermission(GENERAL_REVOKE_ACTION_ID, pendingRoot, EVERYWHERE);

        // Revoke these powers from the outgoing root.
        _revokePermission(GENERAL_GRANT_ACTION_ID, currentRoot, EVERYWHERE);
        _revokePermission(GENERAL_REVOKE_ACTION_ID, currentRoot, EVERYWHERE);

        // Complete the root transfer and reset the pending root.
        _setRoot(pendingRoot_);
        _setPendingRoot(address(0));
    }


    /**
     * @notice Sets a new delay `delay` for action `actionId`.
     * @dev This function can never be called directly - it is only ever called as part of a scheduled execution by
     * the TimelockExecutor after after calling `scheduleDelayChange`.
     */
    function setDelay(bytes32 actionId, uint256 delay) external onlyExecutor {
        _delaysPerActionId[actionId] = delay;
        emit ActionDelaySet(actionId, delay);
    }

    /**
     * @notice Schedules an execution to set action `actionId`'s delay to `newDelay`.
     */
    function scheduleDelayChange(
        bytes32 actionId,
        uint256 newDelay,
        address[] memory executors
    ) external returns (uint256 scheduledExecutionId) {
        require(newDelay <= MAX_DELAY, "DELAY_TOO_LARGE");
        require(isRoot(msg.sender), "SENDER_IS_NOT_ROOT");

        // The delay change is scheduled so that it's never possible to execute an action in a shorter time than the
        // current delay.
        //
        // If we're reducing the action's delay then we must first wait for the difference between the two delays.
        // This means that if we immediately schedule the action for execution once the delay is reduced, then
        // these two delays combined will result in the original delay.
        // For example, if an action's delay is 20 days and we wish to reduce it to 5 days, we need to wait 15 days
        // before the new shorter delay is effective, to make it impossible to execute the action before the full
        // original 20-day delay period has elapsed.
        //
        // If we're increasing the delay on an action, we could in principle execute this change immediately, since the
        // larger delay would fulfill the original constraint imposed by the first delay.
        // For example, if we wish to increase the delay of an action from 5 days to 20 days, there is no need to wait
        // as it would not be possible to execute the action with a delay shorter than the initial 5 days at any point.
        //
        // However, not requiring a delay to increase an action's delay creates an issue: it would be possible to
        // effectively disable actions by setting huge delays (e.g. 2 years) for them. Because of this, all delay
        // changes are subject to a minimum execution delay, to allow for proper scrutiny of these potentially
        // dangerous actions.

        uint256 actionDelay = _delaysPerActionId[actionId];
        uint256 executionDelay = newDelay < actionDelay
            ? Math.max(actionDelay - newDelay, MINIMUM_CHANGE_DELAY_EXECUTION_DELAY)
            : MINIMUM_CHANGE_DELAY_EXECUTION_DELAY;

        bytes32 scheduleDelayActionId = getScheduleDelayActionId(actionId);
        bytes memory data = abi.encodeWithSelector(this.setDelay.selector, actionId, newDelay);
        return _scheduleWithDelay(scheduleDelayActionId, address(this), data, executionDelay, executors);
    }


     /**
     * @notice Schedules an arbitrary execution of `data` in target `where`.
     */
    function schedule(
        address where,
        bytes memory data,
        address[] memory executors
    ) external returns (uint256 scheduledExecutionId) {
        // Allowing scheduling arbitrary calls into the TimelockAuthorizer is dangerous.
        //
        // It is expected that only the `root` account can initiate a root transfer as this condition is enforced
        // by the `scheduleRootChange` function which is the expected method of scheduling a call to `setPendingRoot`.
        // If a call to `setPendingRoot` could be scheduled using this function as well as `scheduleRootChange` then
        // accounts other than `root` could initiate a root transfer (provided they had the necessary permission).
        // Similarly, `setDelay` can only be called if scheduled via `scheduleDelayChange`.
        //
        // For this reason we disallow this function from scheduling calls to functions on the Authorizer to ensure that
        // these actions can only be scheduled through specialised functions.
        require(where != address(this), "CANNOT_SCHEDULE_AUTHORIZER_ACTIONS");

        // We also disallow the TimelockExecutor from attempting to call into itself. Otherwise the above protection
        // could be bypassed by wrapping a call to `setPendingRoot` inside of a call causing the TimelockExecutor to
        // reenter itself, essentially hiding the fact that `where == address(this)` inside `data`.
        //
        // Note: The TimelockExecutor only accepts calls from the TimelockAuthorizer (i.e. not from itself) so this
        // scenario should be impossible but this check is cheap so we enforce it here as well anyway.
        require(where != executor, "ATTEMPTING_EXECUTOR_REENTRANCY");

        bytes32 actionId = getActionId(_decodeSelector(data));
        require(hasPermission(actionId, msg.sender, where), "SENDER_DOES_NOT_HAVE_PERMISSION");
        return _schedule(actionId, where, data, executors);
    }

    /**
     * @notice Executes a scheduled action `scheduledExecutionId`.
     */
    function execute(uint256 scheduledExecutionId) external nonReentrant returns (bytes memory result) {
        require(scheduledExecutionId < _scheduledExecutions.length, "ACTION_DOES_NOT_EXIST");
        ScheduledExecution storage scheduledExecution = _scheduledExecutions[scheduledExecutionId];
        require(!scheduledExecution.executed, "ACTION_ALREADY_EXECUTED");
        require(!scheduledExecution.cancelled, "ACTION_ALREADY_CANCELLED");

        bytes32 actionId = getActionId(_decodeSelector(scheduledExecution.data));

        // solhint-disable-next-line not-rely-on-time
        require(isDelayExemptedActionId[actionId] ||  
            block.timestamp >= scheduledExecution.executableAt, "ACTION_NOT_YET_EXECUTABLE");

        if (scheduledExecution.protected) {
            // Protected scheduled executions can only be executed by a set of accounts designated by the original
            // scheduler.
            require(isExecutor[scheduledExecutionId][msg.sender], "SENDER_IS_NOT_EXECUTOR");
        }

        scheduledExecution.executed = true;

        // Note that this is the only place in the entire contract we perform a non-view call to an external contract,
        // i.e. this is the only context in which this contract can be re-entered, and by this point we've already
        // completed all state transitions.
        // This results in the scheduled execution being marked as 'executed' during its execution, but that should not
        // be an issue.
        result = TimelockExecutor(executor).execute(scheduledExecution.where, scheduledExecution.data);
        emit ExecutionExecuted(scheduledExecutionId);
    }

     /**
     * @notice Cancels a scheduled action `scheduledExecutionId`.
     * @dev The permission to cancel a scheduled action is the same one used to schedule it.
     *
     * Note that in the case of cancelling a malicious granting or revocation of permissions to an address,
     * we must assume that the granter/revoker status of all non-malicious addresses will be revoked as calls to
     * manageGranter/manageRevoker have no delays associated with them.
     */
    function cancel(uint256 scheduledExecutionId) external {
        require(scheduledExecutionId < _scheduledExecutions.length, "ACTION_DOES_NOT_EXIST");
        ScheduledExecution storage scheduledExecution = _scheduledExecutions[scheduledExecutionId];

        require(!scheduledExecution.executed, "ACTION_ALREADY_EXECUTED");
        require(!scheduledExecution.cancelled, "ACTION_ALREADY_CANCELLED");

        // The permission to cancel a scheduled action is the same one used to schedule it.
        // The root address may cancel any action even without this permission.
        bytes32 actionId = getActionId(_decodeSelector(scheduledExecution.data));
        require(
            hasPermission(actionId, msg.sender, scheduledExecution.where) || isRoot(msg.sender),
            "SENDER_IS_NOT_CANCELER"
        );

        scheduledExecution.cancelled = true;
        emit ExecutionCancelled(scheduledExecutionId);
    }



    function delayExemptActionId(bytes32 actionId) external {
        require(msg.sender == executor || isRoot(msg.sender), "CAN_ONLY_BE_SCHEDULED");
        isDelayExemptedActionId[actionId] = true;
    }

    function removeDelayExmptionFromActionId(bytes32 actionId) external onlyExecutor {
        require(msg.sender == executor || isRoot(msg.sender), "CAN_ONLY_BE_SCHEDULED");
        isDelayExemptedActionId[actionId] = false;
    }


    /**
     * @notice Schedules a grant permission to `account` for action `actionId` in target `where`.
     */
    function scheduleGrantPermission(
        bytes32 actionId,
        address account,
        address where,
        address[] memory executors
    ) external returns (uint256 scheduledExecutionId) {
        require(canGrantPermission(actionId, msg.sender, where), "SENDER_IS_NOT_GRANTER");
        bytes memory data = abi.encodeWithSelector(this.grantPermissions.selector, _ar(actionId), account, _ar(where));
        bytes32 grantPermissionId = getGrantPermissionActionId(actionId);
        return _schedule(grantPermissionId, address(this), data, executors);
    }

    /**
     * @notice Schedules a revoke permission from `account` for action `actionId` in target `where`.
     */
    function scheduleRevokePermission(
        bytes32 actionId,
        address account,
        address where,
        address[] memory executors
    ) external returns (uint256 scheduledExecutionId) {
        require(canRevokePermission(actionId, msg.sender, where), "SENDER_IS_NOT_REVOKER");
        bytes memory data = abi.encodeWithSelector(this.revokePermissions.selector, _ar(actionId), account, _ar(where));
        bytes32 revokePermissionId = getRevokePermissionActionId(actionId);
        return _schedule(revokePermissionId, address(this), data, executors);
    }

    function _schedule(
        bytes32 actionId,
        address where,
        bytes memory data,
        address[] memory executors
    ) private returns (uint256 scheduledExecutionId) {
        uint256 delay = _delaysPerActionId[actionId];
        require(delay > 0, "CANNOT_SCHEDULE_ACTION");
        return _scheduleWithDelay(actionId, where, data, delay, executors);
    }

    function _scheduleWithDelay(
        bytes32 actionId,
        address where,
        bytes memory data,
        uint256 delay,
        address[] memory executors
    ) private returns (uint256 scheduledExecutionId) {
        scheduledExecutionId = _scheduledExecutions.length;
        emit ExecutionScheduled(actionId, scheduledExecutionId);

        // solhint-disable-next-line not-rely-on-time
        uint256 executableAt = block.timestamp + delay;
        bool protected = executors.length > 0;

        _scheduledExecutions.push(
            ScheduledExecution({
                where: where,
                data: data,
                executed: false,
                cancelled: false,
                protected: protected,
                executableAt: executableAt
            })
        );

        for (uint256 i = 0; i < executors.length; i++) {
            // Note that we allow for repeated executors - this is not an issue
            isExecutor[scheduledExecutionId][executors[i]] = true;
            emit ExecutorCreated(scheduledExecutionId, executors[i]);
        }
    }

    function _decodeSelector(bytes memory data) internal pure returns (bytes4) {
        // The bytes4 type is left-aligned and padded with zeros: we make use of that property to build the selector
        if (data.length < 4) return bytes4(0);
        return bytes4(data[0]) | (bytes4(data[1]) >> 8) | (bytes4(data[2]) >> 16) | (bytes4(data[3]) >> 24);
    }

    function _ar(bytes32 item) private pure returns (bytes32[] memory result) {
        result = new bytes32[](1);
        result[0] = item;
    }

    function _ar(address item) private pure returns (address[] memory result) {
        result = new address[](1);
        result[0] = item;
    }




  
    
}