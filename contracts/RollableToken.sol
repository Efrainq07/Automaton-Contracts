// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

abstract contract RollableToken is ERC721, Ownable {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    address public litPKP;
    string public unpopulatedTokenURI;

    uint256 public next_token_id = 0;
    uint256 public cost = 0;
    uint256 public rerollCost = 0;

    mapping (uint256=>string) uris;
    mapping (uint256=>uint256) public tokenRandomizingBlock;
    mapping (uint256=>bool) public isPopulated;


    constructor(
        string memory contractName,
        string memory contractSymbol,
        address litPKP_,
        string memory unpopulatedTokenURI_,
        uint256 cost_,
        uint256 rerollCost_) ERC721(contractName, contractSymbol) {
        litPKP = litPKP_;
        unpopulatedTokenURI = unpopulatedTokenURI_;
        cost = cost_;
        rerollCost = rerollCost_;
    }

    function mint(address to) external payable returns (uint256 tokenId){
        require(cost <= msg.value, "Insufficient payable value.");
        _safeMint(to, next_token_id);
        setTokenURI(next_token_id, unpopulatedTokenURI);
        tokenRandomizingBlock[next_token_id] = block.number;
        next_token_id += 1;
        if(cost < msg.value){
            payable(msg.sender).transfer(msg.value - cost);
        }
        return next_token_id - 1;
    }

    function reroll(uint256 tokenId) external payable {
        _requireOwned(tokenId);
        require(ownerOf(tokenId) == msg.sender, "Caller is not owner of token.");
        require(rerollCost <= msg.value, "Insufficient payable value.");
        require(!isPopulated[tokenId], "Cannot reroll populated token.");
        tokenRandomizingBlock[next_token_id] = block.number;
        if(rerollCost < msg.value){
            payable(msg.sender).transfer(msg.value - rerollCost);
        }
    }

    function setTokenURI(uint256 tokenId, string memory uri) internal{
        _requireOwned(tokenId);
        uris[tokenId] = uri;
    }

    function tokenURI(uint256 tokenId) override public view virtual returns (string memory){
        _requireOwned(tokenId);
        return uris[tokenId];
    }

    function setCost(uint256 newCost) public onlyOwner {
        cost = newCost;
    }

    function populateURI(uint256 tokenId, string memory metadataURI, bytes memory signature) public {
        require(SignatureChecker.isValidSignatureNow(litPKP,keccak256(abi.encodePacked(tokenId,metadataURI)).toEthSignedMessageHash(),signature), "Token URI not signed correctly.");
        setTokenURI(tokenId, metadataURI);
        isPopulated[tokenId] = true;
    }

}