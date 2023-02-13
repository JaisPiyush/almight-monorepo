//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@almight/modules/openzeppelin-contracts/contracts/security/Pausable.sol";


abstract contract TemporarilyPausable is Pausable {

    // solhint-disable not-rely-on-time
    bool private _paused;
    uint256 public constant MAX_PAUSE_DURATION = 90 days;
    uint256 public constant DEFAULT_PAUSE_DURATION = 5 days;
    uint256 private _pauseDuration;
    uint32 private _pausedOn;
    
    constructor(uint256 pauseDuration_) Pausable() {

        if (pauseDuration_ == 0) {
            _pauseDuration = DEFAULT_PAUSE_DURATION;
        }else {
            _pauseDuration = pauseDuration_ > MAX_PAUSE_DURATION ? MAX_PAUSE_DURATION : pauseDuration_;
        }
    }


    function _pause() internal virtual override whenNotPaused {
        _paused = true;
        _pausedOn = uint32(block.timestamp);
        emit Paused(_msgSender());

    }

    function _setPauseDuration(uint256 pauseDuration_) internal virtual whenNotPaused {
        _pauseDuration = pauseDuration_;
    } 

    function pauseDuration() public view returns (uint256) {
        return _pauseDuration;
    }

    function pausedOn() public view returns (uint32) {
        return _pausedOn;
    }

    function paused() public view override returns (bool) {
        return _paused && uint32(block.timestamp) - _pausedOn < _pauseDuration;
    }

}