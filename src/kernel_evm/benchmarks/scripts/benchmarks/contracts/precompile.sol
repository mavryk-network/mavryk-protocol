pragma solidity ^0.8.17;

contract Precompile {

    function identity_precompile() public {
        address(2).call(abi.encode(0));
    }

    function sha_precompile() public{
        address(3).call(abi.encode(0));
    }   

    function ripemd160_precompile() public{
        address(4).call(abi.encode(0));
    }   

     function withdraw_precompile() public {
        bytes memory input = hex"cda4fee200000000";
        address(32).call{value: 10000}(abi.encode(input));
    }
}
