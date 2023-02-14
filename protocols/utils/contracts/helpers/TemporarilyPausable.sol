//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@almight/modules/openzeppelin-contracts/contracts/security/Pausable.sol";


abstract contract TemporarilyPausable is Pausable {

    // solhint-disable not-rely-on-time
    bool private _paused;
    uint256 public constant MAX_PAUSE_DURATION = 90 days;
    uint256 public constant DEFAULT_PAUSE_DURATION = 5 days;
    uint256 public pauseDuration;
    uint32 private _pausedOn;
    

    function _estimatePauseDuration(uint256 duration) private pure returns(uint256) {
        if (duration == 0) {
           return DEFAULT_PAUSE_DURATION;
        }else {
            return duration > MAX_PAUSE_DURATION ? MAX_PAUSE_DURATION : duration;
        }
    }

    function _pause(uint256 duration) internal virtual whenNotPaused {
        _paused = true;
        pauseDuration = _estimatePauseDuration(duration);
        _pausedOn = uint32(block.timestamp);
        emit Paused(_msgSender());

    }

    function _pause() internal virtual override whenNotPaused {
        _pause(0);
    }

    function pausedOn() public view returns (uint32) {
        return _pausedOn;
    }

    function paused() public view override returns (bool) {
        return _paused && uint32(block.timestamp) - _pausedOn < pauseDuration;
    }

}