//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;


import "@almight/contract-interfaces/contracts/utils/authorizers/IAccessAuthorizer.sol";

interface ITimelockAuthorizer is IAccessAuthorizer {

    function MAX_DELAY() external view returns(uint256);
    function MINIMUM_CHANGE_DELAY_EXECUTION_DELAY() external view returns(uint256);
    function SCHEDULE_DELAY_ACTION_ID() external view returns(bytes32);

    struct ScheduledExecution {
        address where;
        bytes data;
        bool executed;
        bool cancelled;
        bool protected;
        uint256 executableAt;
    }

    /**
     * @notice Emitted when a new execution `scheduledExecutionId` is scheduled.
     */
    event ExecutionScheduled(bytes32 indexed actionId, uint256 indexed scheduledExecutionId);

    /**
     * @notice Emitted when an executor is created for a scheduled execution `scheduledExecutionId`.
     */
    event ExecutorCreated(uint256 indexed scheduledExecutionId, address indexed executor);

    /**
     * @notice Emitted when an execution `scheduledExecutionId` is executed.
     */
    event ExecutionExecuted(uint256 indexed scheduledExecutionId);

    /**
     * @notice Emitted when an execution `scheduledExecutionId` is cancelled.
     */
    event ExecutionCancelled(uint256 indexed scheduledExecutionId);

    /**
     * @notice Emitted when a new `delay` is set in order to perform action `actionId`.
     */
    event ActionDelaySet(bytes32 indexed actionId, uint256 delay);
    /**
     * @notice Emitted when a new `root` is set.
     */
    event RootSet(address indexed root);

    /**
     * @notice Emitted when a new `root` is set.
     */
    event PendingRootSet(address indexed root);

    function root() external view returns(address);

    function isRoot(address) external view returns(bool);

    function pendingRoot() external view returns(address);
    /**
     * @notice Returns the delay required to transfer the root address.
     */
    function rootTransferDelay() external view returns(uint256);

    function executor() external view returns(address);

    function getScheduleDelayActionId(bytes32 actionId) external view returns(bytes32);

    function getActionIdDelay(bytes32 actionId) external view returns(uint256);

    function isDelayExemptedActionId(bytes32 actionId) external view returns(bool);

    function delayExemptActionId(bytes32 actionId) external;
    function removeDelayExmptionFromActionId(bytes32 actionId) external;

    function getScheduledExecution(uint256 scheduledExecutionId) external view returns (ScheduledExecution memory);
    function isExecutor(uint256 scheduledExecutionId, address account) external view returns (bool);
    function canExecute(uint256 scheduledExecutionId) external view returns (bool);
    function scheduleRootChange(address newRoot, address[] memory executors) 
        external returns (uint256 scheduledExecutionId);
    function setPendingRoot(address pendingRoot) external;
    function claimRoot() external;
    function setDelay(bytes32 actionId, uint256 delay) external;
    function scheduleDelayChange(
        bytes32 actionId,
        uint256 newDelay,
        address[] memory executors
    ) external returns (uint256 scheduledExecutionId);

    function schedule(
        address where,
        bytes memory data,
        address[] memory executors
    ) external returns (uint256 scheduledExecutionId);

    function execute(uint256 scheduledExecutionId) external returns (bytes memory result);
    function cancel(uint256 scheduledExecutionId) external;

    function scheduleGrantPermission(
        bytes32 actionId,
        address account,
        address where,
        address[] memory executors
    ) external returns (uint256 scheduledExecutionId);

    function scheduleRevokePermission(
        bytes32 actionId,
        address account,
        address where,
        address[] memory executors
    ) external returns (uint256 scheduledExecutionId);








}