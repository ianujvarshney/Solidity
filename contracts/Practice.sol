// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SmartMatrixForsage {

    struct User {
        uint id;
        address referrer;
        uint partnersCount;
        mapping(uint8 => bool) activeX3Levels;
        mapping(uint8 => bool) activeX6Levels;
        mapping(uint8 => X3) x3Matrix;
        mapping(uint8 => X6) x6Matrix;
    }
    
    struct X3 {
        address currentReferrer;
        address[] referrals;
        bool blocked;
        uint reinvestCount;
    }
    
    struct X6 {
        address currentReferrer;
        address[] firstLevelReferrals;
        address[] secondLevelReferrals;
        bool blocked;
        uint reinvestCount;
        address closedPart;
    }

    uint8 public constant LAST_LEVEL = 12;
    mapping(address => User) public users;
    mapping(uint => address) public idToAddress;
    mapping(uint => address) public userIds;
    mapping(address => uint) public balances; 
    uint public lastUserId = 2;
    address public owner;
    mapping(uint8 => uint) public levelPrice;

    event Registration(address indexed user, address indexed referrer, uint indexed userId, uint referrerId);
    event Reinvest(address indexed user, address indexed currentReferrer, address indexed caller, uint8 matrix, uint8 level);
    event Upgrade(address indexed user, address indexed referrer, uint8 matrix, uint8 level);
    event NewUserPlace(address indexed user, address indexed referrer, uint8 matrix, uint8 level, uint8 place);
    event MissedEthReceive(address indexed receiver, address indexed from, uint8 matrix, uint8 level);
    event SentExtraEthDividends(address indexed from, address indexed receiver, uint8 matrix, uint8 level);
    
    constructor(address ownerAddress) {
        levelPrice[1] = 0.025 ether;
        for (uint8 i = 2; i <= LAST_LEVEL; i++) {
            levelPrice[i] = levelPrice[i-1] * 2;
        }

        owner = ownerAddress;
        User storage user = users[ownerAddress];
        user.id = 1;
        user.referrer = address(0);
        user.partnersCount = 0;
        for (uint8 i = 1; i <= LAST_LEVEL; i++) {
            user.activeX3Levels[i] = true;
            user.activeX6Levels[i] = true;
        }
        idToAddress[1] = ownerAddress;
        userIds[1] = ownerAddress;
    }
    
    // Receive function to handle plain Ether transfers
    receive() external payable {
        registration(msg.sender, owner);
    }

    // Fallback function to handle calls with data or Ether
    fallback() external payable {
        if (msg.data.length == 0) {
            registration(msg.sender, owner);
        } else {
            registration(msg.sender, bytesToAddress(msg.data));
        }
    }

    function registrationExt(address referrerAddress) external payable {
        registration(msg.sender, referrerAddress);
    }
    
    function buyNewLevel(uint8 matrix, uint8 level) external payable {
        require(isUserExists(msg.sender), "User does not exist. Register first.");
        require(matrix == 1 || matrix == 2, "Invalid matrix");
        require(msg.value == levelPrice[level], "Invalid price");
        require(level > 1 && level <= LAST_LEVEL, "Invalid level");

        if (matrix == 1) {
            require(!users[msg.sender].activeX3Levels[level], "Level already activated");

            if (users[msg.sender].x3Matrix[level-1].blocked) {
                users[msg.sender].x3Matrix[level-1].blocked = false;
            }
               
            address freeX3Referrer = findFreeX3Referrer(msg.sender, level);
            users[msg.sender].x3Matrix[level].currentReferrer = freeX3Referrer;
            users[msg.sender].activeX3Levels[level] = true;
            updateX3Referrer(msg.sender, freeX3Referrer, level);
            
            emit Upgrade(msg.sender, freeX3Referrer, 1, level);

        } else {
            require(!users[msg.sender].activeX6Levels[level], "Level already activated"); 

            if (users[msg.sender].x6Matrix[level-1].blocked) {
                users[msg.sender].x6Matrix[level-1].blocked = false;
            }

            address freeX6Referrer = findFreeX6Referrer(msg.sender, level);
            
            users[msg.sender].activeX6Levels[level] = true;
            updateX6Referrer(msg.sender, freeX6Referrer, level);
            
            emit Upgrade(msg.sender, freeX6Referrer, 2, level);
        }
    }    
    
    function registration(address userAddress, address referrerAddress) private {
        require(msg.value == 0.05 ether, "Registration cost 0.05 ETH");
        require(!isUserExists(userAddress), "User already exists");
        require(isUserExists(referrerAddress), "Referrer does not exist");
        
        uint32 size;
        assembly {
            size := extcodesize(userAddress)
        }
        require(size == 0, "Cannot be a contract");
        
        User storage user = users[userAddress];
        user.id = lastUserId;
        user.referrer = referrerAddress;
        user.partnersCount = 0;
        
        users[referrerAddress].partnersCount++;
        idToAddress[lastUserId] = userAddress;
        userIds[lastUserId] = userAddress;
        lastUserId++;
        
        user.activeX3Levels[1] = true; 
        user.activeX6Levels[1] = true;
        
        address freeX3Referrer = findFreeX3Referrer(userAddress, 1);
        user.x3Matrix[1].currentReferrer = freeX3Referrer;
        updateX3Referrer(userAddress, freeX3Referrer, 1);

        updateX6Referrer(userAddress, findFreeX6Referrer(userAddress, 1), 1);
        
        emit Registration(userAddress, referrerAddress, user.id, users[referrerAddress].id);
    }
    
    function updateX3Referrer(address userAddress, address referrerAddress, uint8 level) private {
        users[referrerAddress].x3Matrix[level].referrals.push(userAddress);

        if (users[referrerAddress].x3Matrix[level].referrals.length < 3) {
            emit NewUserPlace(userAddress, referrerAddress, 1, level, uint8(users[referrerAddress].x3Matrix[level].referrals.length));
            return sendETHDividends(referrerAddress, userAddress, 1, level);
        }
        
        emit NewUserPlace(userAddress, referrerAddress, 1, level, 3);
        // Close matrix
        users[referrerAddress].x3Matrix[level].referrals = new address[](0);
        if (!users[referrerAddress].activeX3Levels[level+1] && level != LAST_LEVEL) {
            users[referrerAddress].x3Matrix[level].blocked = true;
        }

        // Create new one by recursion
        if (referrerAddress != owner) {
            // Check referrer active level
            address freeReferrerAddress = findFreeX3Referrer(referrerAddress, level);
            if (users[referrerAddress].x3Matrix[level].currentReferrer != freeReferrerAddress) {
                users[referrerAddress].x3Matrix[level].currentReferrer = freeReferrerAddress;
            }
            
            users[referrerAddress].x3Matrix[level].reinvestCount++;
            emit Reinvest(referrerAddress, freeReferrerAddress, userAddress, 1, level);
            updateX3Referrer(referrerAddress, freeReferrerAddress, level);
        } else {
            sendETHDividends(owner, userAddress, 1, level);
            users[owner].x3Matrix[level].reinvestCount++;
            emit Reinvest(owner, address(0), userAddress, 1, level);
        }
    }

    function updateX6Referrer(address userAddress, address referrerAddress, uint8 level) private {
        require(users[referrerAddress].activeX6Levels[level], "Referrer level is inactive");
        
        if (users[referrerAddress].x6Matrix[level].firstLevelReferrals.length < 2) {
            users[referrerAddress].x6Matrix[level].firstLevelReferrals.push(userAddress);
            emit NewUserPlace(userAddress, referrerAddress, 2, level, uint8(users[referrerAddress].x6Matrix[level].firstLevelReferrals.length));
            
            // Set current level
            users[userAddress].x6Matrix[level].currentReferrer = referrerAddress;

            if (referrerAddress == owner) {
                return sendETHDividends(referrerAddress, userAddress, 2, level);
            }
            
            address ref = users[referrerAddress].x6Matrix[level].firstLevelReferrals[0];
            if (users[ref].x6Matrix[level].secondLevelReferrals.length < 4) {
                users[ref].x6Matrix[level].secondLevelReferrals.push(userAddress);
                emit NewUserPlace(userAddress, ref, 2, level, uint8(users[ref].x6Matrix[level].secondLevelReferrals.length + 2));
                return sendETHDividends(ref, userAddress, 2, level);
            }

            return updateX6ReferrerSecondLevel(userAddress, ref, level);
        }
        
        users[referrerAddress].x6Matrix[level].secondLevelReferrals.push(userAddress);

        if (users[referrerAddress].x6Matrix[level].closedPart != address(0)) {
            if ((users[referrerAddress].x6Matrix[level].firstLevelReferrals[0] == 
                users[referrerAddress].x6Matrix[level].firstLevelReferrals[1]) &&
                (users[referrerAddress].x6Matrix[level].firstLevelReferrals[0] ==
                users[referrerAddress].x6Matrix[level].closedPart)) {

                updateX6(userAddress, referrerAddress, level, true);
                return updateX6ReferrerSecondLevel(userAddress, referrerAddress, level);
            } else if (users[referrerAddress].x6Matrix[level].firstLevelReferrals[0] == 
                users[referrerAddress].x6Matrix[level].closedPart) {
                updateX6(userAddress, referrerAddress, level, true);
                return updateX6ReferrerSecondLevel(userAddress, referrerAddress, level);
            } else {
                updateX6(userAddress, referrerAddress, level, false);
                return updateX6ReferrerSecondLevel(userAddress, referrerAddress, level);
            }
        }

        if (users[referrerAddress].x6Matrix[level].firstLevelReferrals[1] == userAddress) {
            updateX6(userAddress, referrerAddress, level, false);
            return updateX6ReferrerSecondLevel(userAddress, referrerAddress, level);
        } else if (users[referrerAddress].x6Matrix[level].firstLevelReferrals[0] == userAddress) {
            updateX6(userAddress, referrerAddress, level, true);
            return updateX6ReferrerSecondLevel(userAddress, referrerAddress, level);
        }
        
        if (users[referrerAddress].x6Matrix[level].firstLevelReferrals.length == 2) {
            if (users[referrerAddress].x6Matrix[level].firstLevelReferrals[0] == 
                users[referrerAddress].x6Matrix[level].firstLevelReferrals[1]) {
                updateX6(userAddress, referrerAddress, level, true);
            } else if (users[referrerAddress].x6Matrix[level].firstLevelReferrals[0] == userAddress) {
                updateX6(userAddress, referrerAddress, level, true);
            } else {
                updateX6(userAddress, referrerAddress, level, false);
            }
        } else if (users[referrerAddress].x6Matrix[level].firstLevelReferrals.length == 1) {
            if (users[referrerAddress].x6Matrix[level].firstLevelReferrals[0] == userAddress) {
                updateX6(userAddress, referrerAddress, level, true);
            } else {
                updateX6(userAddress, referrerAddress, level, false);
            }
        }

        updateX6ReferrerSecondLevel(userAddress, referrerAddress, level);
    }
    
    function updateX6(address userAddress, address referrerAddress, uint8 level, bool x6) private {
        if (!x6) {
            users[referrerAddress].x6Matrix[level].closedPart = userAddress;
        }
        users[referrerAddress].x6Matrix[level].secondLevelReferrals.push(userAddress);
        
        if (users[referrerAddress].x6Matrix[level].secondLevelReferrals.length < 4) {
            emit NewUserPlace(userAddress, referrerAddress, 2, level, uint8(users[referrerAddress].x6Matrix[level].secondLevelReferrals.length + 2));
            return sendETHDividends(referrerAddress, userAddress, 2, level);
        }

        emit NewUserPlace(userAddress, referrerAddress, 2, level, 6);
        users[referrerAddress].x6Matrix[level].secondLevelReferrals = new address[](0);
        if (!users[referrerAddress].activeX6Levels[level+1] && level != LAST_LEVEL) {
            users[referrerAddress].x6Matrix[level].blocked = true;
        }

        users[referrerAddress].x6Matrix[level].reinvestCount++;

        if (referrerAddress != owner) {
            address freeReferrerAddress = findFreeX6Referrer(referrerAddress, level);

            emit Reinvest(referrerAddress, freeReferrerAddress, userAddress, 2, level);
            updateX6Referrer(referrerAddress, freeReferrerAddress, level);
        } else {
            sendETHDividends(owner, userAddress, 2, level);
            emit Reinvest(owner, address(0), userAddress, 2, level);
        }
    }

    function updateX6ReferrerSecondLevel(address userAddress, address referrerAddress, uint8 level) private {
        if (users[referrerAddress].x6Matrix[level].secondLevelReferrals.length < 4) {
            return sendETHDividends(referrerAddress, userAddress, 2, level);
        }

        address[] memory x6 = users[referrerAddress].x6Matrix[level].firstLevelReferrals;

        if (x6.length == 2) {
            if (x6[0] == x6[1]) {
                updateX6(userAddress, referrerAddress, level, true);
            } else if (x6[0] == userAddress) {
                updateX6(userAddress, referrerAddress, level, true);
            } else {
                updateX6(userAddress, referrerAddress, level, false);
            }
        } else if (x6.length == 1) {
            if (x6[0] == userAddress) {
                updateX6(userAddress, referrerAddress, level, true);
            } else {
                updateX6(userAddress, referrerAddress, level, false);
            }
        }
    }

    function findFreeX3Referrer(address userAddress, uint8 level) public view returns(address) {
        while (true) {
            if (users[users[userAddress].referrer].activeX3Levels[level]) {
                return users[userAddress].referrer;
            }
            userAddress = users[userAddress].referrer;
        }
    }
    
    function findFreeX6Referrer(address userAddress, uint8 level) public view returns(address) {
        while (true) {
            if (users[users[userAddress].referrer].activeX6Levels[level]) {
                return users[userAddress].referrer;
            }
            userAddress = users[userAddress].referrer;
        }
    }
    
    function usersActiveX3Levels(address userAddress, uint8 level) public view returns(bool) {
        return users[userAddress].activeX3Levels[level];
    }

    function usersActiveX6Levels(address userAddress, uint8 level) public view returns(bool) {
        return users[userAddress].activeX6Levels[level];
    }

    function usersX3Matrix(address userAddress, uint8 level) public view returns(address, address[] memory, bool, uint) {
        return (users[userAddress].x3Matrix[level].currentReferrer,
                users[userAddress].x3Matrix[level].referrals,
                users[userAddress].x3Matrix[level].blocked,
                users[userAddress].x3Matrix[level].reinvestCount);
    }
    
    function usersX6Matrix(address userAddress, uint8 level) public view returns(address, address[] memory, address[] memory, bool, uint, address) {
        return (users[userAddress].x6Matrix[level].currentReferrer,
                users[userAddress].x6Matrix[level].firstLevelReferrals,
                users[userAddress].x6Matrix[level].secondLevelReferrals,
                users[userAddress].x6Matrix[level].blocked,
                users[userAddress].x6Matrix[level].reinvestCount,
                users[userAddress].x6Matrix[level].closedPart);
    }

    function isUserExists(address user) public view returns (bool) {
        return (users[user].id != 0);
    }
    
    function bytesToAddress(bytes memory bys) private pure returns (address addr) {
        assembly {
            addr := mload(add(bys, 20))
        }
    }

    function sendETHDividends(address userAddress, address _from, uint8 matrix, uint8 level) private {
        (bool success, ) = payable(userAddress).call{value: levelPrice[level]}("");
        if (success) {
            return;
        }
        emit MissedEthReceive(userAddress, _from, matrix, level);
    }
}
