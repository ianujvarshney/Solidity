// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract VotingMachine{

    struct vote{
        address userAdress;
        bool choice;
    }
    struct voter{
        string name;
        bool voted;
    }

    uint private countResult = 0;
    uint public finalResult = 0;
    uint public totalVoter = 0;
    uint public totalValue = 0;

    address public ballotOfficialAddress;
    string public ballotOfficialName;
    string public proposal;
    
    mapping(uint => vote) private votes;
    mapping(address => voter) public voterRegister;
    
    enum State {Created, Voting, Ended}
    State public state;


    modifier condition(bool _condition){
        require(_condition);
        _;
    }
    modifier onlyOfficial(){
        require(msg.sender == ballotOfficialAddress);
        _;
    }

    modifier inState(State _state){
        require(state == _state);
        _;
    }
    constructor(
        string memory _ballotOfficialName;
        string memory _proposal
    ) public {
        ballotOfficialAddress == msg.sender;
        ballotOfficialName = _ballotOfficialName;
        proposal = _proposal;
        state  State.;
    }

    function addVoter() public{
        address _voterAddress;
        string memory _voterName;
    }

    function StartVote(){
        
    }

    function doVote(){

    }

    function endVote(){

    }


}   