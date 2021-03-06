//SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "hardhat/console.sol";

contract MVMarket is ReentrancyGuard {
  using Counters for Counters.Counter;

  Counters.Counter private _tokenIds;
  Counters.Counter private _tokensSold;

  address payable owner;

  uint256 listingPrice = 100000 wei;

  constructor() {
    owner = payable(msg.sender);
  }

  struct MarketToken {
    uint256 itemId;
    address nftContract;
    uint256 tokenId;
    address payable seller;
    address payable owner;
    uint256 price;
    bool sold;
  }

  mapping(uint256 => MarketToken) private idToMarketToken;

  event MarketTokenMinted(
    uint256 indexed itemId,
    address indexed nftContract,
    uint256 indexed tokenId,
    address seller,
    address owner,
    uint256 price,
    bool sold
  );

  function getListingPrice() public view returns (uint256) {
    return listingPrice;
  }

  function makeMarketItem(
    address nftContract,
    uint256 tokenId,
    uint256 price
  ) public payable nonReentrant {
    require(price > 0, "Price must be at least one wei");
    require(msg.value == listingPrice, "Price must be equal to listing price");
    _tokenIds.increment();
    uint256 itemId = _tokenIds.current();
    idToMarketToken[itemId] = MarketToken(
      itemId,
      nftContract,
      tokenId,
      payable(msg.sender),
      payable(address(0)),
      price,
      false
    );
    //transfering the minted tokens from contract/owner/msg.sender to buyer/minter
    IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

    emit MarketTokenMinted(
      itemId,
      nftContract,
      tokenId,
      msg.sender,
      address(0),
      price,
      false
    );
  }

  function createMarketSale(address nftContract, uint256 itemId)
    public
    payable
    nonReentrant
  {
    uint256 price = idToMarketToken[itemId].price;
    uint256 tokenId = idToMarketToken[itemId].tokenId;
    require(
      msg.value == price,
      "Please submit the asking price in order to continue"
    );
    //transfer the amount to the seller
    idToMarketToken[itemId].seller.transfer(msg.value);
    //transfer token/NFT from contract address to the buyer
    IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
    idToMarketToken[itemId].owner = payable(msg.sender);
    idToMarketToken[itemId].sold = true;
    _tokensSold.increment();
    payable(owner).transfer(listingPrice);
  }

  //return the 'unsold' nft's
  function getMarketTokens() public view returns (MarketToken[] memory) {
    uint256 itemCount = _tokenIds.current();
    uint256 unsoldItemCount = _tokenIds.current() - _tokensSold.current();
    uint256 currentIndex = 0;
    MarketToken[] memory items = new MarketToken[](unsoldItemCount);
    for (uint256 i = 0; i < itemCount; i++) {
      if (idToMarketToken[i + 1].owner == address(0)) {
        uint256 currentId = i + 1;
        MarketToken storage currentItem = idToMarketToken[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    }
    return items;
  }

  //return nfts that the user has purchased
  function getMyNFTs() public view returns (MarketToken[] memory) {
    uint256 totalItemCount = _tokenIds.current();
    uint256 itemCount = 0;
    uint256 currentIndex = 0;
    for (uint256 i = 0; i < totalItemCount; i++) {
      if (idToMarketToken[i + 1].owner == msg.sender) {
        itemCount += 1;
      }
    }
    //second loop to retrieve the tokenIds within the tokenCount beloning to owner/msg.sender
    //array to hold the tokenIds
    MarketToken[] memory items = new MarketToken[](itemCount);
    for (uint256 i = 0; i < totalItemCount; i++) {
      if (idToMarketToken[i + 1].owner == msg.sender) {
        uint256 currentId = idToMarketToken[i + 1].itemId;
        //assign the currentId to the MarketToken[] array
        MarketToken storage currentItem = idToMarketToken[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    }
    return items;
  }

  function getItemsCreated() public view returns (MarketToken[] memory) {
    //instead of owner tokens it will retrieve .seller tokens
    uint256 totalItemCount = _tokenIds.current();
    uint256 itemCount = 0;
    uint256 currentIndex = 0;
    for (uint256 i = 0; i < totalItemCount; i++) {
      if (idToMarketToken[i + 1].seller == msg.sender) {
        itemCount += 1;
      }
    }
    MarketToken[] memory items = new MarketToken[](itemCount);
    for (uint256 i = 0; i < totalItemCount; i++) {
      if (idToMarketToken[i + 1].seller == msg.sender) {
        uint256 currentId = idToMarketToken[i + 1].itemId;
        MarketToken storage currentItem = idToMarketToken[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    }
    return items;
  }
}
