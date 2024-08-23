// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Lottery{
    address payable public manager;
    address payable[] public players;

    constructor(){
        manager = payable(msg.sender);
    }

    function duplicateplayer() private view returns(bool){
        for(uint i = 0; i < players.length; i++)
        {
            if(players[i] == msg.sender) return true;
        }
        return false;
    }

    function enter() payable public{
        require(msg.sender != manager, "Manager can't be join!");
        require(duplicateplayer() == false, "One player can join one time!");
        require(msg.value >= 1 ether, "price should be at least one");
        players.push(payable(msg.sender));
    }

    function random() view private returns(uint){
        return uint(sha256(abi.encodePacked(block.difficulty, block.number,players)));
    }

    function winnerpicker() public{
        require(msg.sender == manager,"only manager can pic the winner");
        uint index = random()%players.length;
        address contractaddress = address(this);
        players[index].transfer(contractaddress.balance);
        players = new address payable[](0);
    }

    function getplayer() view public returns(address payable[] memory){
        return players;
    }

}


