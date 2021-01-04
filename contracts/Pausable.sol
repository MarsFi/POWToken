pragma solidity ^0.5.0;

contract Pausable {

    event Paused();

    event Unpaused();

    bool private _paused;

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused() {
        require(_paused, "Pausable: not paused");
        _;
    }

    /**
     * @dev Called by a pauser to pause, triggers stopped state.
     */
    function _pause() internal {
        _paused = true;
        emit Paused();
    }

    /**
     * @dev Called by a pauser to unpause, returns to normal state.
     */
    function _unpause() internal {
        _paused = false;
        emit Unpaused();
    }
}
