// SPDX-License-Identifier: MIT
pragma solidity >= 0.5.0 < 0.9.0;

contract Testing
{
   
    string public name;

    function getter() public pure returns(uint)
    {
        uint age = 10;
        return age;
    }
}