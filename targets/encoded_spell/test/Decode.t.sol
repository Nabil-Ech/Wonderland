// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;
import "forge-std/Test.sol";

contract DecodeTest is Test {
    function test_decode_short() external {
        bytes memory short_data = new bytes(200);
        try this.tryDecode(short_data) returns (bytes32[8] memory r) {
            emit log("SUCCESS 200 bytes");
            emit log_bytes32(r[0]);
        } catch {
            emit log("REVERT 200 bytes");
        }
        bytes memory full_data = new bytes(256);
        try this.tryDecode(full_data) returns (bytes32[8] memory r2) {
            emit log("SUCCESS 256 bytes");
            emit log_bytes32(r2[0]);
        } catch {
            emit log("REVERT 256 bytes");
        }
    }
    function tryDecode(bytes memory data) external pure returns (bytes32[8] memory) {
        return abi.decode(data, (bytes32[8]));
    }
}

contract DecodeZeroTest is Test {
    function test_decode_zero_and_256() external {
        // Empty bytes
        try this.tryDecode(new bytes(0)) returns (bytes32[8] memory) {
            emit log("SUCCESS 0 bytes");
        } catch {
            emit log("REVERT 0 bytes");
        }
        // 256 zero bytes → weakSeals all zero
        try this.tryDecode(new bytes(256)) returns (bytes32[8] memory r) {
            emit log("SUCCESS 256 bytes");
            emit log_bytes32(r[0]);
        } catch {
            emit log("REVERT 256 bytes");
        }
    }
    function tryDecode(bytes memory d) external pure returns (bytes32[8] memory) {
        return abi.decode(d, (bytes32[8]));
    }
}
