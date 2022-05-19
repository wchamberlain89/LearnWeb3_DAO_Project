// SPDX-License-Identifier: MIT
pragma solidity 0.8.0^;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IFakeNFTMarketPlace {
  function getPrice() external view returns(uint256);

  function available(uint256 _tokenId) external view returns (bool);

  function purchase(uint256 _tokenId) external payable;
}

interface ICryptoDevsNFT {
  function balanceOf(address owner) external view returns (uint256);

  function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
}


contract CryptoDevsDAO is ownable {
  struct Proposal {
    uint256 nftTokenId;
    uint256 deadline;
    uint256 yayVotes;
    uint256 nayVotes;
    bool executed;
    mapping(uint256 => bool) voters;
  }

  enum Vote {
    YAY,
    NAY
  }

  mapping(uint256 => Proposal) public proposals;

  uint256 public numProposals;

  IFakeNFTMarketplace nftMarketplace;
  ICryptoDevesNFT cryptoDevsNFT;

  // Create a payable constructor which initializes the contract
  constructor(address _nftMarketPlace, address _cryptoDevsNFT) payable {
    nftMartketplace = IFakeNFTMarketplace(_nftMartketPlace);
    cryptoDevsNFT = ICryptoDevsNFT(_cryptoDevsNFT);
  }

  modifier nftHolderOnly() {
    require(cryptoDevsNFT.balanceOf(msg.sender) > 0, "You are not a DAO Member");
    _;
  }

  modifier activeProposalsOnly(uint256 proposalIndex) {
    require(
      proposals[proposalIndex].deadline > block.timestamp,
      "The Deadline for this Proposal is past"
    );
    _;
  }

  modifier inactiveProposalOnly(uint256 proposalIndex) {
    require(
      proposals[proposalIndex].deadline <= block.timestamp,
      "The Deadline has not been exceeded"
    );
    require(
      proposals[proposalsIndex].executed == false,
      "Proposal has already been executed"
    );
    _;
  }

  /// @dev createProposal allows a CryptoDevsNFT holder to create a new proposal in the DAO
  /// @param _nftTokenId - the tokenID of the NFT to be purchased from FakeNFTMarketplace if this proposal passes
  /// @return Returns the proposal index for the newly created proposal
  function createProposal(uint256 _nftTokenId)
      external
      nftHolderOnly
      returns (uint256)
  {
      require(nftMarketplace.available(_nftTokenId), "NFT_NOT_FOR_SALE");
      Proposal storage proposal = proposals[numProposals];
      proposal.nftTokenId = _nftTokenId;
      // Set the proposal's voting deadline to be (current time + 5 minutes)
      proposal.deadline = block.timestamp + 5 minutes;

      numProposals++;

      return numProposals - 1;
  }

  /// @dev voteOnProposal allows a CryptoDevsNFT holder to cast their vote on an active proposal
  /// @param proposalIndex - the index of the proposal to vote on in the proposals array
  /// @param vote - the type of vote they want to cast
  function voteOnProposal(uint256 proposalIndex, Vote vote)
    external
    nftHolderOnly
    activeProposalOnly(proposalIndex)
  {
    Proposal storage proposal = proposals[proposalIndex];

    uint256 voterNFTBalance = cryptoDevsNFT.balanceOf(msg.sender);
    uint256 numVotes = 0;

    for (uint256 i = 0; i < voterNFTBalance; i++) {
      uint256 tokenId = cryptoDevsNFT.tokenOfOwnerByIndex(msg.sender, i);
      if (proposal.voters[tokenId] == false) {
        numVotes++;
        proposal.voters[tokenId] = true;
      }
    }

    require(numVotes > 0, "Already Voted");

    if (vote == Vote.YAY) {
      proposal.yayVotes += numVotes;
    } else {
      proposal.nayVotes += numVotes;
    }
  }

  /// @dev executeProposal allows any CryptoDevsNFT holder to execute a proposal after it's deadline has been exceeded
  /// @param proposalIndex - the index of the proposal to execute in the proposals array
  function executeProposal(uint256 proposalIndex)
    external
    nftHolderOnly
    inactiveProposalOnly(proposalIndex)
  {
    Proposal storage proposal = proposals[proposalIndex];

    // If the proposalhas more Yay votes than Nay votes
    // purchase the NFT from the FakeNFTMarketplace
    if (proposal.yayVotes > proposal.nayVotes) {
      uint256 nftPrice = nftMarketplace.getPrice();
      require(address(this).balance >= nftPrice, "Not Enough Funds");
      nftMarketplace.purchase(value: nftPrice)(proposal.nftTokenId);
    }
    proposal.executed = true;
  }

  /// @dev withdrawEther allows the contract owner to withdraw the ETH from the contract
  function withdrawEther() external onlyOwner {
    payable(owner()).transfer(address(this).balance);
  }
  
  // The following two functions allow the contract to accept ETH deposits
  // directly from a wallet without calling a function
  receive() external payable {}

  fallback() external payable {}
}