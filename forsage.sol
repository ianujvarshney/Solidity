// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Forsage {
    struct User {
        uint id;
        address referrer;
        uint partnersCount;
        mapping(uint8 => bool) activeX3Levels;
        mapping(uint8 => bool) activeX6Levels;
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
    mapping(address => mapping(uint8 => X3)) public x3Matrices;
    mapping(address => mapping(uint8 => X6)) public x6Matrices;
    mapping(uint => address) public idToAddress;
    uint public lastUserId = 2;
    address public owner;

    mapping(uint8 => uint) public levelPrice;

    event Registration(
        address indexed user,
        address indexed referrer,
        uint indexed userId,
        uint referrerId
    );
    event Reinvest(
        address indexed user,
        address indexed currentReferrer,
        address indexed caller,
        uint8 matrix,
        uint8 level
    );
    event Upgrade(
        address indexed user,
        address indexed referrer,
        uint8 matrix,
        uint8 level
    );
    event NewUserPlace(
        address indexed user,
        address indexed referrer,
        uint8 matrix,
        uint8 level,
        uint8 place
    );
    event MissedEthReceive(
        address indexed receiver,
        address indexed from,
        uint8 matrix,
        uint8 level
    );
    event SentDividends(
        address indexed from,
        address indexed receiver,
        uint8 matrix,
        uint8 level
    );

    constructor(address ownerAddress) {
        levelPrice[1] = 0.025 ether;
        for (uint8 i = 2; i <= LAST_LEVEL; i++) {
            levelPrice[i] = levelPrice[i - 1] * 2;
        }

        owner = ownerAddress;

        User storage user = users[ownerAddress];
        user.id = 1;
        user.referrer = address(0);
        user.partnersCount = uint(0);

        idToAddress[1] = ownerAddress;

        for (uint8 i = 1; i <= LAST_LEVEL; i++) {
            user.activeX3Levels[i] = true;
            user.activeX6Levels[i] = true;
        }
    }

    receive() external payable {
        registration(msg.sender, owner);
    }

    fallback() external payable {
        registration(msg.sender, bytesToAddress(msg.data));
    }

    function registrationExt(address referrerAddress) external payable {
        registration(msg.sender, referrerAddress);
    }

    function buyNewLevel(uint8 matrix, uint8 level) external payable {
        require(isUserExists(msg.sender), "User is not registered. Register first.");
        require(matrix == 1 || matrix == 2, "Invalid matrix.");
        require(msg.value == levelPrice[level], "Invalid price.");
        require(level > 1 && level <= LAST_LEVEL, "Invalid level.");

        if (matrix == 1) {
            require(!users[msg.sender].activeX3Levels[level], "Level already activated.");
            if (x3Matrices[msg.sender][level - 1].blocked) {
                x3Matrices[msg.sender][level - 1].blocked = false;
            }

            address freeX3Referrer = findFreeX3Referrer(msg.sender, level);
            users[msg.sender].activeX3Levels[level] = true;
            updateX3Referrer(msg.sender, freeX3Referrer, level);

            emit Upgrade(msg.sender, freeX3Referrer, 1, level);
        } else {
            require(!users[msg.sender].activeX6Levels[level], "Level already activated.");
            if (x6Matrices[msg.sender][level - 1].blocked) {
                x6Matrices[msg.sender][level - 1].blocked = false;
            }

            address freeX6Referrer = findFreeX6Referrer(msg.sender, level);
            users[msg.sender].activeX6Levels[level] = true;
            updateX6Referrer(msg.sender, freeX6Referrer, level);

            emit Upgrade(msg.sender, freeX6Referrer, 2, level);
        }
    }

    function registration(address userAddress, address referrerAddress) private {
        require(msg.value == 0.05 ether, "Registration cost is 0.05 ether.");
        require(!isUserExists(userAddress), "User already exists.");
        require(isUserExists(referrerAddress), "Referrer does not exist.");

        uint32 size;
        assembly {
            size := extcodesize(userAddress)
        }
        require(size == 0, "Cannot be a contract.");

        User storage user = users[userAddress];
        user.id = lastUserId;
        user.referrer = referrerAddress;
        user.partnersCount = 0;

        idToAddress[lastUserId] = userAddress;
        lastUserId++;

        users[referrerAddress].partnersCount++;

        user.activeX3Levels[1] = true;
        user.activeX6Levels[1] = true;

        address freeX3Referrer = findFreeX3Referrer(userAddress, 1);
        x3Matrices[userAddress][1].currentReferrer = freeX3Referrer;
        updateX3Referrer(userAddress, freeX3Referrer, 1);

        updateX6Referrer(userAddress, findFreeX6Referrer(userAddress, 1), 1);

        emit Registration(userAddress, referrerAddress, user.id, users[referrerAddress].id);
    }

    function updateX3Referrer(address userAddress, address referrerAddress, uint8 level) private {
        X3 storage x3Matrix = x3Matrices[referrerAddress][level];
        x3Matrix.referrals.push(userAddress);

        if (x3Matrix.referrals.length < 3) {
            emit NewUserPlace(userAddress, referrerAddress, 1, level, uint8(x3Matrix.referrals.length));
            sendETHDividends(referrerAddress);
            return;
        }

        emit NewUserPlace(userAddress, referrerAddress, 1, level, 3);
        delete x3Matrix.referrals;  

        if (!users[referrerAddress].activeX3Levels[level + 1] && level != LAST_LEVEL) {
            x3Matrix.blocked = true;
        }

        if (referrerAddress != owner) {
            address freeReferrerAddress = findFreeX3Referrer(referrerAddress, level);
            if (x3Matrix.currentReferrer != freeReferrerAddress) {
                x3Matrix.currentReferrer = freeReferrerAddress;
            }

            x3Matrix.reinvestCount++;
            emit Reinvest(referrerAddress, freeReferrerAddress, userAddress, 1, level);
            updateX3Referrer(referrerAddress, freeReferrerAddress, level);
        } else {
            sendETHDividends(owner);
            x3Matrix.reinvestCount++;
            emit Reinvest(owner, address(0), userAddress, 1, level);
        }
    }

    function updateX6Referrer(address userAddress, address referrerAddress, uint8 level) private {
        require(users[referrerAddress].activeX6Levels[level], "Referrer level is inactive.");

        X6 storage x6Matrix = x6Matrices[referrerAddress][level];

        if (x6Matrix.firstLevelReferrals.length < 2) {
            x6Matrix.firstLevelReferrals.push(userAddress);
            emit NewUserPlace(userAddress, referrerAddress, 2, level, uint8(x6Matrix.firstLevelReferrals.length));

            x6Matrix.currentReferrer = referrerAddress;

            if (referrerAddress == owner) {
                sendETHDividends(referrerAddress);
                return;
            }

            address ref = x6Matrix.currentReferrer;
            x6Matrices[ref][level].secondLevelReferrals.push(userAddress);

            uint len = x6Matrices[ref][level].firstLevelReferrals.length;

            if ((len == 2) &&
                (x6Matrices[ref][level].firstLevelReferrals[0] == referrerAddress) &&
                (x6Matrices[ref][level].firstLevelReferrals[1] == referrerAddress)) {
                if (x6Matrices[ref][level].secondLevelReferrals.length == 4) {
                    x6Matrices[ref][level].blocked = true;
                    sendETHDividends(ref);
                }
                updateX6Referrer(userAddress, findFreeX6Referrer(ref, level), level);
            } else {
                updateX6Referrer(userAddress, findFreeX6Referrer(ref, level), level);
            }
        } else {
            address freeX6Referrer = findFreeX6Referrer(referrerAddress, level);
            updateX6ReferrerSecondLevel(userAddress, freeX6Referrer, level);
        }
    }

    function updateX6ReferrerSecondLevel(address userAddress, address referrerAddress, uint8 level) private {
        X6 storage x6Matrix = x6Matrices[referrerAddress][level];

        if (x6Matrix.secondLevelReferrals.length == 4) {
            x6Matrix.blocked = true;
            delete x6Matrix.secondLevelReferrals;  // Clear the array
            delete x6Matrix.firstLevelReferrals;  // Clear the array
        }

        x6Matrix.secondLevelReferrals.push(userAddress);
        emit NewUserPlace(userAddress, referrerAddress, 2, level, uint8(x6Matrix.secondLevelReferrals.length));

        if (x6Matrix.secondLevelReferrals.length == 4) {
            x6Matrix.blocked = true;
            sendETHDividends(referrerAddress);

            if (referrerAddress != owner) {
                address freeReferrerAddress = findFreeX6Referrer(referrerAddress, level);
                updateX6Referrer(userAddress, freeReferrerAddress, level);
            } else {
                sendETHDividends(owner);
            }
        }
    }

    function findFreeX3Referrer(address userAddress, uint8 level) public view returns (address) {
        while (true) {
            if (users[users[userAddress].referrer].activeX3Levels[level]) {
                return users[userAddress].referrer;
            }
            userAddress = users[userAddress].referrer;
            if (userAddress == address(0)) {
                return address(0);
            }
        }
    }

    function findFreeX6Referrer(address userAddress, uint8 level) public view returns (address) {
        while (true) {
            if (users[users[userAddress].referrer].activeX6Levels[level]) {
                return users[userAddress].referrer;
            }
            userAddress = users[userAddress].referrer;
            if (userAddress == address(0)) {
                return address(0);
            }
        }
    }

    function sendETHDividends(address userAddress) private {
        address payable payableUserAddress = payable(userAddress);
        uint256 amount = 1 ether; // Adjust as needed
        if (!payableUserAddress.send(amount)) {
            payableUserAddress.transfer(address(this).balance);
        }
    }

    function isUserExists(address userAddress) public view returns (bool) {
        return users[userAddress].id != 0;
    }

    function bytesToAddress(bytes memory bys) public pure returns (address addr) {
        assembly {
            addr := mload(add(bys, 20))
        }
    }
}
