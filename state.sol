// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 < 0.9.0;

contract state
{
    uint[4] public arr = [21,23,23,53];

    function setter(uint index, uint value) public 
    {
        arr[index] = value;
    }
}