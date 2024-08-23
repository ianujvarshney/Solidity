// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RonxRegistration {
    address public owner;
    uint256 public cycleCount;
    uint256 private usersInCurrentCycle;

    struct User {
        string firstName;
        string lastName;
        string email;
        string password;
        string profilePic;
        string userId;
        string uplineId; // Added upline ID field
        address walletAddress;
        string referralLink;
        uint256 cycle; // Track the cycle in which the user is registered
    }

    mapping(address => User) public users;
    address[] public userAddresses;

    event UserRegistered(address indexed walletAddress, string userId, string uplineId, string referralLink, uint256 cycle);

    constructor() {
        owner = msg.sender; // Set the contract deployer as the owner
        cycleCount = 1; // Start with the first cycle
        usersInCurrentCycle = 0; // Initialize the counter for users in the current cycle
    }

    function registerUser(
        string memory _firstName,
        string memory _lastName,
        string memory _email,
        string memory _password,
        string memory _profilePic,
        string memory _uplineId // Upline ID parameter
    ) public payable {
        require(bytes(users[msg.sender].userId).length == 0, "User already registered.");
        // require(msg.value == 25 ether, "Registration requires at least 25 Ether.");

        string memory userId = generateUserId();

        // Enforce upline ID requirement except for the first user
        if (keccak256(abi.encodePacked(userId)) != keccak256(abi.encodePacked("1000001"))) {
            require(bytes(_uplineId).length > 0, "Upline ID is required.");
        } else {
            _uplineId = ""; // No upline required for the first user
        }

        // Check if the cycle should be incremented after every three new users
        if (usersInCurrentCycle == 4) {
            cycleCount++;
            usersInCurrentCycle = 0; // Reset the counter for the new cycle
        }

        usersInCurrentCycle++; // Increment the user counter within the current cycle

        string memory referralLink = generateReferralLink(userId);

        users[msg.sender] = User({
            firstName: _firstName,
            lastName: _lastName,
            email: _email,
            password: _password,
            profilePic: _profilePic,
            userId: userId,
            uplineId: _uplineId, // Store upline ID
            walletAddress: msg.sender,
            referralLink: referralLink,
            cycle: cycleCount // Store the current cycle
        });

        userAddresses.push(msg.sender);
        payable(owner).transfer(msg.value);
        emit UserRegistered(msg.sender, userId, _uplineId, referralLink, cycleCount);
    }

    function generateUserId() internal view returns (string memory) {
        if (userAddresses.length == 0) {
            return "1000001"; 
        } 
        else {
            string memory lastUserId = users[userAddresses[userAddresses.length - 1]].userId;
            uint256 lastUserIdInt = stringToUint(lastUserId);
            uint256 newUserIdInt = lastUserIdInt + 1;
            return toString(newUserIdInt);
        }
    }

    function generateReferralLink(string memory userId) internal pure returns (string memory) {
        return string(abi.encodePacked("https://ronxplatform.com/referral/", userId));
    }

    function stringToUint(string memory s) internal pure returns (uint256) {
        bytes memory b = bytes(s);
        uint256 result = 0;
        for (uint i = 0; i < b.length; i++) {
            if (uint8(b[i]) >= 48 && uint8(b[i]) <= 57) {
                result = result * 10 + (uint8(b[i]) - 48);
            }
        }
        return result;
    }

    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function getAllUsers() public view returns (User[] memory) {
        User[] memory allUsers = new User[](userAddresses.length);
        for (uint i = 0; i < userAddresses.length; i++) {
            allUsers[i] = users[userAddresses[i]];
        }
        return allUsers;
    }

    function getUserByUserId(string memory _userId) public view returns (User memory) {
        for (uint i = 0; i < userAddresses.length; i++) {
            if (keccak256(abi.encodePacked(users[userAddresses[i]].userId)) == keccak256(abi.encodePacked(_userId))) {
                return users[userAddresses[i]];
            }
        }
        revert("User ID not found.");
    }
}