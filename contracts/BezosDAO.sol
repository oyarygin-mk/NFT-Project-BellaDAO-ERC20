// File: contracts/BezosDAO.sol

//SPDX-License-Identifier: MIT
//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)

pragma solidity ^0.8.0;









contract BezosDAO is ERC721A, IERC2981, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using Strings for uint256;

    Counters.Counter private tokenCounter;

    string private baseURI = "ipfs://QmU8QTcxtjbxH8LnxZWAm7YWhUy5HaUq5b4req5AVsN1RL";
    address private openSeaProxyRegistryAddress = 0xa5409ec958C83C3f309868babACA7c86DCB077c1;
    bool private isOpenSeaProxyActive = true;

    uint256 public constant MAX_MINTS_PER_TX = 10;
    uint256 public maxSupply = 888;

    uint256 public constant PUBLIC_SALE_PRICE = 0.01 ether;
    uint256 public NUM_FREE_MINTS = 288;
    bool public isPublicSaleActive = true;




    // ============ ACCESS CONTROL/SANITY MODIFIERS ============

    modifier publicSaleActive() {
        require(isPublicSaleActive, "Public sale is not open");
        _;
    }



    modifier maxMintsPerTX(uint256 numberOfTokens) {
        require(
            numberOfTokens <= MAX_MINTS_PER_TX,
            "Max mints per transaction exceeded"
        );
        _;
    }

    modifier canMintNFTs(uint256 numberOfTokens) {
        require(
            totalSupply() + numberOfTokens <=
                maxSupply,
            "Not enough mints remaining to mint"
        );
        _;
    }

    modifier freeMintsAvailable() {
        require(
            totalSupply() <=
                NUM_FREE_MINTS,
            "Not enough free mints remain"
        );
        _;
    }



    modifier isCorrectPayment(uint256 price, uint256 numberOfTokens) {
        if(totalSupply()>NUM_FREE_MINTS){
        require(
            (price * numberOfTokens) == msg.value,
            "Incorrect ETH value sent"
        );
        }
        _;
    }


    constructor(
    ) ERC721A("BezosDAO", "BEZOS", 100, maxSupply) {
    }

    // ============ PUBLIC FUNCTIONS FOR MINTING ============

    function mint(uint256 numberOfTokens)
        external
        payable
        nonReentrant
        isCorrectPayment(PUBLIC_SALE_PRICE, numberOfTokens)
        publicSaleActive
        canMintNFTs(numberOfTokens)
    {

        _safeMint(msg.sender, numberOfTokens);
    }



    //A simple free mint function to avoid confusion
    function freeMint()
        external
        nonReentrant
        publicSaleActive
        canMintNFTs(1)
        maxMintsPerTX(1)
        freeMintsAvailable()
    {
        _safeMint(msg.sender, 1);
    }




    // ============ PUBLIC READ-ONLY FUNCTIONS ============

    function getBaseURI() external view returns (string memory) {
        return baseURI;
    }

    // ============ OWNER-ONLY ADMIN FUNCTIONS ============

    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    // function to disable gasless listings for security in case
    // opensea ever shuts down or is compromised
    function setIsOpenSeaProxyActive(bool _isOpenSeaProxyActive)
        external
        onlyOwner
    {
        isOpenSeaProxyActive = _isOpenSeaProxyActive;
    }

    function setIsPublicSaleActive(bool _isPublicSaleActive)
        external
        onlyOwner
    {
        isPublicSaleActive = _isPublicSaleActive;
    }

    function setNumFreeMints(uint256 _numfreemints)
        external
        onlyOwner
    {
        NUM_FREE_MINTS = _numfreemints;
    }


    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function withdrawTokens(IERC20 token) public onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        token.transfer(msg.sender, balance);
    }



    // ============ SUPPORTING FUNCTIONS ============

    function nextTokenId() private returns (uint256) {
        tokenCounter.increment();
        return tokenCounter.current();
    }

    // ============ FUNCTION OVERRIDES ============

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721A, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev Override isApprovedForAll to allowlist user's OpenSea proxy accounts to enable gas-less listings.
     */
    function isApprovedForAll(address owner, address operator)
        public
        view
        override
        returns (bool)
    {
        // Get a reference to OpenSea's proxy registry contract by instantiating
        // the contract using the already existing address.
        ProxyRegistry proxyRegistry = ProxyRegistry(
            openSeaProxyRegistryAddress
        );
        if (
            isOpenSeaProxyActive &&
            address(proxyRegistry.proxies(owner)) == operator
        ) {
            return true;
        }

        return super.isApprovedForAll(owner, operator);
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(_exists(tokenId), "Nonexistent token");

        return
            string(abi.encodePacked(baseURI, "/", (tokenId+1).toString(), ".json"));
    }

    /**
     * @dev See {IERC165-royaltyInfo}.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        require(_exists(tokenId), "Nonexistent token");

        return (address(this), SafeMath.div(SafeMath.mul(salePrice, 5), 100));
    }
}

// These contract definitions are used to create a reference to the OpenSea
// ProxyRegistry contract by using the registry's address (see isApprovedForAll).
contract OwnableDelegateProxy {

}

contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}