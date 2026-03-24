// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title AI Proof of Reserves - Lite
 * @author Elrom / StandardBitcoin - BNB Hack 2026
 * @notice Lightweight version for BNB Chain testnet deployment.
 *         AI agents verify cross-chain reserves via MCP tools.
 * @dev Optimized for low gas deployment.
 */
contract AIPoRLite {
    address public owner;
    uint80 public latestRound;
    uint256 public lastUpdate;

    struct Report {
        int256 reserves;
        uint8 confidence;
        uint256 timestamp;
        bytes32 evidence;
    }

    mapping(uint80 => Report) public reports;
    mapping(address => bool) public agents;

    event ReportPublished(uint80 indexed id, int256 reserves, uint8 confidence);
    event AgentSet(address indexed agent, bool authorized);

    constructor() {
        owner = msg.sender;
        agents[msg.sender] = true;
        lastUpdate = block.timestamp;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "!owner");
        _;
    }

    modifier onlyAgent() {
        require(agents[msg.sender], "!agent");
        _;
    }

    function publishReport(
        int256 _reserves,
        uint8 _confidence,
        bytes32 _evidence
    ) external onlyAgent {
        require(_reserves >= 0 && _confidence <= 100);
        latestRound++;
        reports[latestRound] = Report(_reserves, _confidence, block.timestamp, _evidence);
        lastUpdate = block.timestamp;
        emit ReportPublished(latestRound, _reserves, _confidence);
    }

    function getLatest() external view returns (
        uint80 id, int256 reserves, uint8 confidence, uint256 ts, bytes32 evidence
    ) {
        Report storage r = reports[latestRound];
        return (latestRound, r.reserves, r.confidence, r.timestamp, r.evidence);
    }

    function setAgent(address _agent, bool _auth) external onlyOwner {
        agents[_agent] = _auth;
        emit AgentSet(_agent, _auth);
    }

    // Chainlink AggregatorV3 compatible
    function decimals() external pure returns (uint8) { return 17; }
    function description() external pure returns (string memory) { return "AI-PoR-BNB"; }
    function version() external pure returns (uint256) { return 1; }

    function latestRoundData() external view returns (
        uint80, int256, uint256, uint256, uint80
    ) {
        Report storage r = reports[latestRound];
        return (latestRound, r.reserves, r.timestamp, r.timestamp, latestRound);
    }
}
