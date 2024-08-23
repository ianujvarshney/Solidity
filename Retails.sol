//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Retail{
    struct Product{
        string name;
        uint256 price;
        uint256 stock;
    }
    mapping(string => Product) public products;
    address payable owner;

    constructor(){
        owner = payable(msg.sender);
    }

    function addprodcut(string memory name, uint256 price, uint256 stock) public {
        require(msg.sender == owner,"Only owner can add products.");  
        products[name] = Product(name,price,stock);  
    }

    function updateProductPrice(string memory name, uint256 price) public {
        require(owner == msg.sender,"only onwer can update the products.");
        require(products[name].price > 0, "Product does't exist.");
        products[name].price = price;
    }

    function updateProductstock(string memory name, uint256 stock) public {
        require(msg.sender == owner, "Only Onwer can update stock.");
        require(products[name].stock > 0,"Product does't exist.");
        products[name].stock = stock;
    }

    function purchased(string memory name, uint256 quantity) public payable {
        require(msg.value == products[name].price*quantity, "Incorrect payment");
        require(quantity <= products[name].stock, "Not enought Stock.");
        products[name].stock -= quantity; 
    }

    function getproduct(string memory name) public view returns(string memory, uint256, uint256){
        return (products[name].name, products[name].price, products[name].stock); 
    }

    function grantAccess(address payable user) public{
          require(msg.sender == owner, "Only Onwer can grant access.");
          owner = user;
    }

    function revokeAccess(address payable user) public{
          require(msg.sender == owner, "Only Onwer can revoke access.");
          require(user != owner, "Cannot revoke access for the current owner.");
          owner = payable(msg.sender);
    }

    function destroy() public{
        require(msg.sender == owner, "only the onwer can destroy the contract.");
        selfdestruct(owner);
    }
}