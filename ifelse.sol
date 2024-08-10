// SPDX-License-Identifier: MIT
pragma solidity >= 0.5.0 < 0.9.0;

 contract Ifelse{

    function check(uint a) public pure returns(string memory)
    {
        string memory value;
        if(a > 5)
        {
            value = "value is greater then 5";
        }
        else if( a < 5)
        {
            value="value is less then 5";
        }
        else{
            value="value is equal to 5";
        }
        return value;
    }
 }