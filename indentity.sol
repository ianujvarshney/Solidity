// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.9.0;

contract Identity {
    string public name;
    uint public age;

    constructor() {
        name = "Anuj";
        age = 25;
    }

    function getName() public view returns (string memory) {
        return name;
    }

    function getAge() public view returns (uint) {
        return age;
    }
}

