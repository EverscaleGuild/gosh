pragma ton-solidity >=0.54.0;

interface ISMVProposal {

function getInitialize(address locker, uint256 _platform_id) external;
function vote (address locker, uint256 id, bool choice, uint128 amount) external responsible returns(bool);
function isCompleted() external responsible returns (optional (bool));

}