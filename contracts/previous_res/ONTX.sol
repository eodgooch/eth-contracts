pragma solidity ^0.5.0;

import "./../libs/token/ERC20/ERC20Extended.sol";
import "./../libs/common/ZeroCopySource.sol";
import "./../libs/common/ZeroCopySink.sol";
import "./../libs/utils/Utils.sol";
import "./../core/v1.0/CrossChainManager/IEthCrossChainManager.sol";
contract ONTX is ERC20Extended {
    struct TxArgs {
        bytes toAddress;
        uint64 amount;
    }

    event UnlockEvent(bytes fromContractAddr, uint64 fromChainId, bytes toAddress, uint64 amount);
    event LockEvent(address thisContract, uint64 chainId, bytes toContract, bytes txArgs);
    
    constructor () public ERC20Detailed("ONT Token", "ONTX", 0) {
        operator = _msgSender();
    }
    
    /* @notice                  This function is meant to be invoked by the ETH crosschain management contract,
    *                           then mint a certin amount of tokens to the designated address since a certain amount 
    *                           was burnt from the source chain invoker.
    *  @param argsBs            The argument bytes recevied by the ethereum business contract, need to be deserialized.
    *                           based on the way of serialization in the source chain contract.
    *  @param fromContractAddr  The source chain contract address
    *  @param fromChainId       The source chain id
    */
    function unlock(bytes memory argsBs, bytes memory fromContractAddr, uint64 fromChainId) onlyManagerContract public returns (bool) {
        TxArgs memory args = _deserializTxArgs(argsBs);

        require(Utils.equalStorage(contractAddrBindChainId[fromChainId], fromContractAddr), "From contract address error!");
        
        require(mint(Utils.bytesToAddress(args.toAddress), uint256(args.amount)), "mint ONTX in unlock method failed!");
        
        emit UnlockEvent(fromContractAddr, fromChainId, args.toAddress, args.amount);
        return true;
    }

    /* @notice                  This function is meant to be invoked by the user,
    *                           a certain amount teokens will be burnt from the invoker/msg.sender immediately.
    *                           Then the same amount of tokens will be mint at the target chain with chainId later.
    *  @param toChainId         The target chain id
    *                           
    *  @param toUserAddr        The address in bytes format to receive same amount of tokens in target chain 
    *  @param amount            The amount of tokens to be crossed from ethereum to the chain with chainId
    */
    function lock(uint64 toChainId, bytes memory toUserAddr, uint64 amount) public returns (bool) {
        TxArgs memory txArgs = TxArgs({
            toAddress: toUserAddr,
            amount: amount
        });

        bytes memory txData;
        // if toChainId is BTC chain, put redeemScript into Args

        txData = _serializeTxArgs(txArgs);
        

        require(burn(uint256(amount)), "Burn msg.sender ONTX tokens failed");

        IEthCrossChainManager eccm = IEthCrossChainManager(managerContract);
        
        require(eccm.crossChain(toChainId, contractAddrBindChainId[toChainId], "unlock", txData), "IEthCrossChainManager crossChain executed error!");

        emit LockEvent(address(this), toChainId, contractAddrBindChainId[toChainId], txData);
        
        return true;

    }

    function _serializeTxArgs(TxArgs memory args) internal pure returns (bytes memory) {
        bytes memory buff;
        buff = abi.encodePacked(
            ZeroCopySink.WriteVarBytes(args.toAddress),
            ZeroCopySink.WriteUint64(args.amount)
            );
        return buff;
    }

    function _deserializTxArgs(bytes memory valueBs) internal pure returns (TxArgs memory) {
        TxArgs memory args;
        uint256 off = 0;
        (args.toAddress, off) = ZeroCopySource.NextVarBytes(valueBs, off);
        (args.amount, off) = ZeroCopySource.NextUint64(valueBs, off);
        return args;
    }
}