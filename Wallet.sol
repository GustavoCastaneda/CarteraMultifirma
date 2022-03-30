// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;


contract CarteraMult {
    event Deposit(address indexed sender, uint amount, uint balance);
    event Submit(uint indexed txId);
    event Approve(address indexed owner, uint indexed txId);
    event Revoke(address indexed owner, uint indexed txId);
    event Execute(uint indexed txId);

    struct Transaction{
        address to;
        uint value;
        bytes data;
        bool executed;

    }

    address[] public owners; 
    mapping (address => bool) public isOwner;
    uint public required;  

    Transaction[] public transactions;
    mapping (uint => mapping(address => bool)) public approved; 

    modifier onlyOwner(){
        require(isOwner[msg.sender], "no duenio");
        _;
    }

    modifier txExists(uint _txId){
        require(_txId < transactions.length, "tx no existe");
        _;
    }
    modifier notApproved(uint _txId) {
        require(!approved[_txId][msg.sender],"tx aprovada!");
        _;
    }
    modifier notExecuted(uint _txId) {
        require(!transactions[_txId].executed, "tx ejecutada");
        _;
    }

    constructor(address[] memory _owners, uint _required){
        require (_owners.length > 0, "duenios requeridos");
        require(
            _required > 0 && _required <= _owners.length,
            "Numero invalido de duenios requeridos"

        );
        
        for (uint i; i < _owners.length; i++){
            address owner = _owners[i];
            require(owner != address(0), "dueno invalido");
            require(!isOwner[owner], "dueno no es unico");

            isOwner[owner] = true;
            owners.push(owner);  
        }
        
        required = _required;
    }
    receive () external payable{
        emit Deposit(msg.sender, msg.value, address(this).balance);

    }

    function submit(address _to, uint _value, bytes calldata _data)
        external
        onlyOwner
    {
        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false
        }));
        emit Submit(transactions.length -1);

    }    
    function approve (uint _txId)
        external 
        onlyOwner
        txExists(_txId)
        notApproved(_txId)
        notExecuted(_txId) 

    {

        approved[_txId][msg.sender] = true; 
        emit Approve(msg.sender, _txId);
    }    

    function _getApprovalCount(uint _txId) private view returns (uint count){
        for (uint i; i < owners.length; i++){
            if (approved[_txId][owners[i]]){
                count += 1;
            }
        }
    }
    
    function execute(uint _txId) external txExists(_txId) notExecuted(_txId) {
        require(_getApprovalCount(_txId) >= required, "aprovadas < requeridas");
        Transaction storage transaction = transactions[_txId];

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "tx sin exito");
        emit Execute(_txId);
    }

    function revoke(uint _txId) 
        external 
        onlyOwner
        txExists(_txId)
        notExecuted(_txId)
    {

        require(approved[_txId][msg.sender], "tx no aprovada");
        approved[_txId][msg.sender] = false;
        emit Revoke(msg.sender, _txId);
    }
}
