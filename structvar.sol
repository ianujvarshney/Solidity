// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;

struct school {
    string name;
    int256 age;
}

contract Structvar {
    school public s1;

    constructor(int256 _age, string memory _name) {
        s1.name = _name;
        s1.age = _age;
    }
}
