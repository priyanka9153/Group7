// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract GGMarket is Ownable {
    using Address for address;
    using Counters for Counters.Counter;
    Counters.Counter private id;
    Counters.Counter private numSold;
    Counters.Counter private numCancelled;

    receive() external payable {}

    enum State {
        INITIATED,
        SOLD,
        CANCELLED
    }

    struct Listing {
        uint256 ListingId;
        address TokenAddress;
        address seller;
        uint256 tokenId;
        uint256 amount;
        uint256 price_each;
        // address buyer;
        State state;
    }

    mapping(uint256 => Listing) private _listings;
    event ListingCreated(
        uint256 indexed ListingId,
        uint256 indexed tokenId,
        uint256 amount,
        uint256 price_each,
        address seller,
        address indexed TokenAddress
    );
    event ListingSold(
        uint256 indexed amount,
        uint256 indexed ListingId,
        uint256 price_each,
        address indexed buyer
    );
    event ListingCancelled(uint256 indexed ListingId, address indexed seller);

    function createListing(
        address _TokenAddress,
        uint256 _amount,
        uint256 _price_each,
        uint256 _tokenId
    ) external {
        require(
            IERC1155(_TokenAddress).balanceOf(_msgSender(), _tokenId) >=
                _amount,
            "You do not have enough tokens"
        );
        id.increment();
        Listing memory newListing;

        newListing.seller = _msgSender();
        newListing.ListingId = id.current();
        newListing.amount = _amount;
        newListing.tokenId = _tokenId;
        newListing.state = State.INITIATED;
        newListing.price_each = _price_each;
        newListing.TokenAddress = _TokenAddress;
        _listings[id.current()] = newListing;
        emit ListingCreated(
            newListing.ListingId,
            newListing.tokenId,
            newListing.amount,
            newListing.price_each,
            newListing.seller,
            newListing.TokenAddress
        );
    }

    function getListings() public view returns (Listing[] memory) {
        Listing[] memory listings = new Listing[](
            id.current() - numSold.current()-numCancelled.current()
        );
        uint256 j = 0;
        for (uint256 i = 1; i <= id.current(); i++) {
            if (_listings[i].state == State.INITIATED) {
                listings[j] = _listings[i];
                j++;
            }
        }
        return listings;
    }

    function getMyListings() public view returns (Listing[] memory) {
        uint256 count = 0;
        for (uint256 i = 1; i <= id.current(); i++) {
            if (_listings[i].seller == _msgSender()) {
                count++;
            }
        }
        Listing[] memory mylistings = new Listing[](count);
        uint256 count2 = 0;
        for (uint256 i = 1; i <= id.current(); i++) {
            if (_listings[i].seller == _msgSender()) {
                mylistings[count2] = _listings[i];
            }
        }
        return mylistings;
    }

    function buyListing(uint256 _id, uint256 _amount) public payable {
        require(_listings[_id].state==State.INITIATED,"The listing is no longer available");
        require(_amount > 0);
        require(
            msg.value >= _listings[_id].price_each * _amount,
            "Insufficient funds"
        );
        require(_listings[_id].amount>=_amount,"Not enough tokens left in this listing");
        require(
            IERC1155(_listings[_id].TokenAddress).balanceOf(
                _listings[_id].seller,
                _listings[_id].tokenId
            ) >= _amount,"Not enough tokens left"
        );
        address payable _seller = payable(_listings[_id].seller);
        (bool sent, ) = _seller.call{value: msg.value}("");
        require(sent, "Transaction failed");
        IERC1155(_listings[_id].TokenAddress).safeTransferFrom(
            _listings[_id].seller,
            _msgSender(),
            _listings[_id].tokenId,
            _amount,
            abi.encodePacked("SafeTransferFrom by GGMarket")
        );
        _listings[_id].amount-=_amount;
        if(IERC1155(_listings[_id].TokenAddress).balanceOf(
                _listings[_id].seller,
                _listings[_id].tokenId
            )==0 || _listings[_id].amount==0){
                _listings[_id].state=State.SOLD;
            }
        emit ListingSold(_amount, _id, _listings[_id].price_each, _msgSender());
    }
    function cancelListing(uint _id) public {
        require(_msgSender()==_listings[_id].seller,"Only seller can cancel the listing");
        _listings[_id].state=State.CANCELLED;
        numCancelled.increment();
        emit ListingCancelled(_id, _msgSender());
    }
}
