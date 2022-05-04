interface IVotingResultRecipient {
    function isCompletedCallback(uint256, address, optional(bool), TvmCell) external;
}