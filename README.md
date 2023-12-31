createListing

- set order creator to msg.sender
- token address
- tokenId
- price
- sign
- deadline
- listing status

preconditions

- owner
  - check that owner is really the owner of tokenId --> ownerOf()
  - check that owner has approved address(this) to spend tokenAddress -->isApprovedForAll()
- token address

  - check if token address is not address(0)
  - check if the address has code

- price
  - check that price > 0
- sign
-
- deadline
  - must be > block.timestamp
- listing status

logic

- store data in storage
- increment id for Listings
- emit event
- listing status is set to active

executeListing(payable)

- listingId

preconditions

- check that listingId< public counter
- check that msg.value == listing.price
- check that block.timestamp <= listing.deadline
- check that signature is signed by listing.owner
- check that status is active

logic

- retrieve data from storage
- transfer ether from buyer to seller
- transfer nft from seller to buyer
- emit event
- set status to inactive
