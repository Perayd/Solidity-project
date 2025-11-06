// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SimpleNFT is ERC721URIStorage, Ownable {
    uint256 public nextTokenId;

    event Minted(address indexed to, uint256 tokenId, string uri);

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}

    /// @notice Owner can mint an NFT to `to` with metadata URI
    function mint(address to, string memory tokenURI_) external onlyOwner returns (uint256) {
        uint256 id = nextTokenId;
        nextTokenId++;
        _safeMint(to, id);
        _setTokenURI(id, tokenURI_);
        emit Minted(to, id, tokenURI_);
        return id;
    }

    /// @notice Owner can batch mint
    function batchMint(address to, string[] calldata uris) external onlyOwner {
        for (uint i = 0; i < uris.length; i++) {
            mint(to, uris[i]);
        }
    }
}
