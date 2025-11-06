// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NFTMarketplace is ReentrancyGuard {
    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price; // price in token or in wei
        bool forToken; // true => price denominated in ERC20 token, false => in ETH
        IERC20 token;  // the ERC20 token (if forToken)
    }

    uint256 public listingCount;
    mapping(uint256 => Listing) public listings;

    event Listed(uint256 indexed listingId, address indexed seller, address nftContract, uint256 tokenId, uint256 price, bool forToken, address tokenAddress);
    event Delisted(uint256 indexed listingId);
    event Purchased(uint256 indexed listingId, address indexed buyer);

    function listForETH(address nftContract, uint256 tokenId, uint256 price) external returns (uint256) {
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        listingCount++;
        listings[listingCount] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            forToken: false,
            token: IERC20(address(0))
        });

        emit Listed(listingCount, msg.sender, nftContract, tokenId, price, false, address(0));
        return listingCount;
    }

    function listForToken(address nftContract, uint256 tokenId, uint256 price, IERC20 token) external returns (uint256) {
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        listingCount++;
        listings[listingCount] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            forToken: true,
            token: token
        });

        emit Listed(listingCount, msg.sender, nftContract, tokenId, price, true, address(token));
        return listingCount;
    }

    function delist(uint256 listingId) external nonReentrant {
        Listing storage l = listings[listingId];
        require(l.seller != address(0), "No listing");
        require(l.seller == msg.sender, "Not seller");

        IERC721(l.nftContract).transferFrom(address(this), l.seller, l.tokenId);
        delete listings[listingId];
        emit Delisted(listingId);
    }

    function buyWithETH(uint256 listingId) external payable nonReentrant {
        Listing storage l = listings[listingId];
        require(l.seller != address(0), "No listing");
        require(!l.forToken, "Listing is for token");
        require(msg.value == l.price, "Incorrect ETH amount");

        address seller = l.seller;
        IERC721(l.nftContract).transferFrom(address(this), msg.sender, l.tokenId);

        // send ether to seller
        payable(seller).transfer(msg.value);

        delete listings[listingId];
        emit Purchased(listingId, msg.sender);
    }

    function buyWithToken(uint256 listingId) external nonReentrant {
        Listing storage l = listings[listingId];
        require(l.seller != address(0), "No listing");
        require(l.forToken, "Listing is for ETH");

        IERC20 token = l.token;
        require(token.transferFrom(msg.sender, l.seller, l.price), "Token transfer failed");

        IERC721(l.nftContract).transferFrom(address(this), msg.sender, l.tokenId);

        delete listings[listingId];
        emit Purchased(listingId, msg.sender);
    }
}
