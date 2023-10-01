// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

contract Lottery is VRFConsumerBaseV2, ConfirmedOwner {
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    address payable[] public players;
    address public manager;
    uint public lotteryId;
    mapping(uint => address payable ) public WinnersBoard;

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }
    
    mapping(uint256 => RequestStatus)
        public s_requests; /* requestId --> requestStatus */
    VRFCoordinatorV2Interface COORDINATOR;

    // Your subscription ID.
    uint64 s_subscriptionId;

    // past requests Id.
    uint256[] public requestIds;
    uint256 public lastRequestId;

    bytes32 keyHash =
        0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;

    uint32 callbackGasLimit = 2_500_000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    uint32 numWords = 2;

    constructor(
        uint64 subscriptionId
    )
        VRFConsumerBaseV2(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625)
        ConfirmedOwner(msg.sender)
    {
        COORDINATOR = VRFCoordinatorV2Interface(
            0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
        );
        s_subscriptionId = subscriptionId;
        manager = msg.sender;
        lotteryId = 1;
    }

    receive() external payable {
        require(msg.value == 10 ether);
        players.push(payable(msg.sender));
    }

    modifier onlyManager{
        require(msg.sender == manager);
        _;
    }

    function getContractBalance() public view onlyManager returns(uint) {
        return address(this).balance;
    }

    function requestRandomWords()
        external
        onlyOwner
        returns (uint256 requestId)
    {
        // Will revert if subscription is not set and funded.
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(_requestId, _randomWords);
    }

    function getRequestStatus(
        uint256 _requestId
    ) public view returns (bool fulfilled, uint256[] memory randomWords) {
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    } 

    // function random() public view returns(uint){
    //     return uint(keccak256(abi.encodePacked(block.difficulty , block.timestamp, players.length)));
    // }

    function pickWinner() public onlyManager {
        require(players.length >= 3);
        (bool fulfilled, uint[] memory randomWords) = getRequestStatus(lastRequestId);
        require(fulfilled, "Random words request is not fulfilled");
        uint index = randomWords[0] % (players.length) + 1;
        address payable winner;
        winner = players[index];
        winner.transfer(getContractBalance());
        WinnersBoard[lotteryId] = players[index];
        lotteryId++;
        players = new address payable[](0);
    }

    function getWinnersBoard(uint _lotteryId) public view returns (address payable) {
        return WinnersBoard[_lotteryId];
    }
}