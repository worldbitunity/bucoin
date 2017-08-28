pragma solidity ^0.4.11;

import "../../contracts/ownership/Contactable.sol";

contract ContactableMock is Contactable {
    function ContactableMock(){
        contactInformation = "info1";
    }
}
