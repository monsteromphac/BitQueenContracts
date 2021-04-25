import "./IERC721Enumerable.sol";

interface IQueens is IERC721Enumerable {
    function isMintedBeforeReveal(uint256 index) external view returns (bool);
}