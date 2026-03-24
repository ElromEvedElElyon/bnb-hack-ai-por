// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title AI-Powered Cross-Chain Proof of Reserves
 * @author Elrom / StandardBitcoin - BNB Hack 2026
 * @notice On-chain verification system where AI agents report and verify
 *         cross-chain asset reserves via MCP (Model Context Protocol) tools.
 * @dev Deployed on BNB Chain. AI agents use MCP servers to query Bitcoin/Solana
 *      custody addresses and publish aggregated reserve data on-chain.
 *
 * Architecture:
 * 1. AI Agent (via MCP) queries Bitcoin/Solana/ETH custody addresses off-chain
 * 2. Agent validates reserves using multiple data sources (consensus)
 * 3. Agent publishes verified reserve totals to this BNB Chain contract
 * 4. Anyone can verify: totalReserves >= totalSupply (fully backed)
 * 5. AI anomaly detection flags suspicious reserve changes
 *
 * Hackathon: BNB Hack Online ($700K)
 * Track: AI + DeFi Infrastructure
 */

contract AIProofOfReserves {

    struct ReserveReport {
        uint80 reportId;
        int256 totalReserves;
        uint256 timestamp;
        address reporter;
        bytes32 evidenceHash;
        uint8 confidenceScore;
        string[] chains;
    }

    struct AssetConfig {
        string name;
        string symbol;
        uint8 decimals;
        bool active;
        uint256 totalSupply;
    }

    struct CustodyAddress {
        string chain;
        string addr;
        bool active;
    }

    struct AnomalyAlert {
        uint256 timestamp;
        string alertType;
        string description;
        uint8 severity;
    }

    address public owner;
    address public pendingOwner;

    mapping(address => bool) public authorizedAgents;
    address[] public agentList;

    mapping(uint80 => ReserveReport) public reports;
    uint80 public latestReportId;

    mapping(bytes32 => AssetConfig) public assets;
    bytes32[] public assetIds;

    CustodyAddress[] public custodyAddresses;

    AnomalyAlert[] public anomalies;
    uint256 public anomalyThresholdPct = 10;

    uint256 public heartbeat = 3600;
    uint256 public lastUpdateTimestamp;

    uint8 public minConfidence = 70;

    event ReserveReportPublished(uint80 indexed reportId, int256 totalReserves, uint8 confidenceScore, address indexed reporter);
    event AgentAuthorized(address indexed agent);
    event AgentRevoked(address indexed agent);
    event AssetRegistered(bytes32 indexed assetId, string name, string symbol);
    event SupplyUpdated(bytes32 indexed assetId, uint256 newSupply);
    event CustodyAddressAdded(string chain, string addr);
    event CustodyAddressRemoved(uint256 index);
    event AnomalyDetected(string alertType, uint8 severity, string description);
    event HeartbeatUpdated(uint256 newHeartbeat);
    event OwnershipTransferStarted(address indexed from, address indexed to);
    event OwnershipTransferred(address indexed from, address indexed to);

    constructor() {
        owner = msg.sender;
        lastUpdateTimestamp = block.timestamp;

        bytes32 busd1Id = keccak256(abi.encodePacked("bUSD1"));
        assets[busd1Id] = AssetConfig({name: "BITCOIN-USD-ONE", symbol: "bUSD1", decimals: 17, active: true, totalSupply: 0});
        assetIds.push(busd1Id);
        emit AssetRegistered(busd1Id, "BITCOIN-USD-ONE", "bUSD1");

        authorizedAgents[msg.sender] = true;
        agentList.push(msg.sender);
        emit AgentAuthorized(msg.sender);
    }

    modifier onlyOwner() { require(msg.sender == owner, "Not owner"); _; }
    modifier onlyAgent() { require(authorizedAgents[msg.sender], "Not authorized agent"); _; }

    function publishReport(int256 _totalReserves, uint8 _confidenceScore, bytes32 _evidenceHash, string[] calldata _chains) external onlyAgent {
        require(_totalReserves >= 0, "Negative reserves");
        require(_confidenceScore <= 100, "Invalid confidence");
        require(_confidenceScore >= minConfidence, "Confidence too low");
        require(_chains.length > 0, "No chains specified");

        if (latestReportId > 0) {
            ReserveReport storage prev = reports[latestReportId];
            if (prev.totalReserves > 0) {
                int256 change = _totalReserves - prev.totalReserves;
                int256 pctChange = (change * 100) / prev.totalReserves;
                if (pctChange < 0) pctChange = -pctChange;
                if (uint256(pctChange) > anomalyThresholdPct) {
                    string memory desc = pctChange > 0 ? "Reserve increase exceeds threshold" : "Reserve decrease exceeds threshold";
                    uint8 severity = uint8(uint256(pctChange) > 50 ? 10 : uint256(pctChange) / 5);
                    anomalies.push(AnomalyAlert({timestamp: block.timestamp, alertType: "RESERVE_CHANGE", description: desc, severity: severity}));
                    emit AnomalyDetected("RESERVE_CHANGE", severity, desc);
                }
            }
        }

        latestReportId++;
        reports[latestReportId] = ReserveReport({reportId: latestReportId, totalReserves: _totalReserves, timestamp: block.timestamp, reporter: msg.sender, evidenceHash: _evidenceHash, confidenceScore: _confidenceScore, chains: _chains});
        lastUpdateTimestamp = block.timestamp;
        emit ReserveReportPublished(latestReportId, _totalReserves, _confidenceScore, msg.sender);
    }

    function isFullyBacked(bytes32 _assetId) external view returns (bool backed, int256 reserves, uint256 supply, uint256 ratio, uint8 confidence) {
        AssetConfig storage asset = assets[_assetId];
        require(asset.active, "Asset not active");
        ReserveReport storage r = reports[latestReportId];
        reserves = r.totalReserves;
        supply = asset.totalSupply;
        confidence = r.confidenceScore;
        if (supply == 0) return (true, reserves, supply, type(uint256).max, confidence);
        ratio = uint256(reserves) * 1e18 / supply;
        backed = uint256(reserves) >= supply;
    }

    function getLatestReport() external view returns (uint80, int256, uint256, address, bytes32, uint8) {
        ReserveReport storage r = reports[latestReportId];
        return (r.reportId, r.totalReserves, r.timestamp, r.reporter, r.evidenceHash, r.confidenceScore);
    }

    function isDataFresh() external view returns (bool) { return (block.timestamp - lastUpdateTimestamp) <= heartbeat; }
    function getAnomalyCount() external view returns (uint256) { return anomalies.length; }

    function getAnomaly(uint256 _index) external view returns (uint256, string memory, string memory, uint8) {
        require(_index < anomalies.length, "Index out of bounds");
        AnomalyAlert storage a = anomalies[_index];
        return (a.timestamp, a.alertType, a.description, a.severity);
    }

    // Chainlink AggregatorV3 Compatibility
    function decimals() external pure returns (uint8) { return 17; }
    function description() external pure returns (string memory) { return "AI-PoR-CrossChain-Reserves-BNB"; }
    function version() external pure returns (uint256) { return 1; }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        ReserveReport storage r = reports[latestReportId];
        return (r.reportId, r.totalReserves, r.timestamp, r.timestamp, r.reportId);
    }

    function getRoundData(uint80 _roundId) external view returns (uint80, int256, uint256, uint256, uint80) {
        ReserveReport storage r = reports[_roundId];
        require(r.timestamp > 0, "Round not found");
        return (r.reportId, r.totalReserves, r.timestamp, r.timestamp, r.reportId);
    }

    // Agent Management
    function authorizeAgent(address _agent) external onlyOwner { require(!authorizedAgents[_agent], "Already authorized"); authorizedAgents[_agent] = true; agentList.push(_agent); emit AgentAuthorized(_agent); }
    function revokeAgent(address _agent) external onlyOwner { require(authorizedAgents[_agent], "Not authorized"); authorizedAgents[_agent] = false; emit AgentRevoked(_agent); }
    function getAgentCount() external view returns (uint256) { return agentList.length; }

    // Asset Management
    function registerAsset(string calldata _name, string calldata _symbol, uint8 _decimals) external onlyOwner returns (bytes32 assetId) {
        assetId = keccak256(abi.encodePacked(_symbol));
        require(!assets[assetId].active, "Asset exists");
        assets[assetId] = AssetConfig({name: _name, symbol: _symbol, decimals: _decimals, active: true, totalSupply: 0});
        assetIds.push(assetId);
        emit AssetRegistered(assetId, _name, _symbol);
    }

    function updateSupply(bytes32 _assetId, uint256 _totalSupply) external onlyAgent { require(assets[_assetId].active, "Asset not active"); assets[_assetId].totalSupply = _totalSupply; emit SupplyUpdated(_assetId, _totalSupply); }
    function getAssetCount() external view returns (uint256) { return assetIds.length; }

    // Custody Address Management
    function addCustodyAddress(string calldata _chain, string calldata _addr) external onlyOwner { custodyAddresses.push(CustodyAddress({chain: _chain, addr: _addr, active: true})); emit CustodyAddressAdded(_chain, _addr); }
    function removeCustodyAddress(uint256 _index) external onlyOwner { require(_index < custodyAddresses.length, "Out of bounds"); custodyAddresses[_index].active = false; emit CustodyAddressRemoved(_index); }
    function getCustodyAddressCount() external view returns (uint256) { return custodyAddresses.length; }

    function getCustodyAddress(uint256 _index) external view returns (string memory, string memory, bool) {
        require(_index < custodyAddresses.length, "Out of bounds");
        CustodyAddress storage c = custodyAddresses[_index];
        return (c.chain, c.addr, c.active);
    }

    // Admin
    function setHeartbeat(uint256 _heartbeat) external onlyOwner { heartbeat = _heartbeat; emit HeartbeatUpdated(_heartbeat); }
    function setMinConfidence(uint8 _minConfidence) external onlyOwner { require(_minConfidence <= 100, "Invalid confidence"); minConfidence = _minConfidence; }
    function setAnomalyThreshold(uint256 _pct) external onlyOwner { anomalyThresholdPct = _pct; }
    function transferOwnership(address _newOwner) external onlyOwner { pendingOwner = _newOwner; emit OwnershipTransferStarted(owner, _newOwner); }
    function acceptOwnership() external { require(msg.sender == pendingOwner, "Not pending owner"); emit OwnershipTransferred(owner, pendingOwner); owner = pendingOwner; pendingOwner = address(0); }
}
