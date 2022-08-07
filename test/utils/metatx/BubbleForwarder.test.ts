import {expect} from 'chai';
import { ethers } from 'hardhat';
import hardhat from 'hardhat';
import {ZERO_ADDRESS, encodePacked, address} from '../../testUtils';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

type Address = string;
type Roles = BigInt;

type Request = {
  network: BigInt,
  chainId: BigInt,
  from: Address,
  onBehalfOf: Address,
  roles: Roles,
  to: Address,
  value: BigInt,
  gas: BigInt,
  nonce: BigInt,
  data: string,
  validUntilTime: BigInt
}

type RawFunctionData = {
  rawData: string
}

const BYTES_32_MAX = BigInt("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF");
const BYTES_32_MID = BigInt("0x0102030405060708091011121314151617181920212223242526272829303132");

const ALL_ROLES = BYTES_32_MAX;
const ADMIN_ROLE = BigInt("0x8000000000000000000000000000000000000000000000000000000000000000");

describe('Execute', async () => {

  const NETWORK_ID = BigInt(1);
  const CHAIN_ID = BigInt(0x7a69); // to match hardhat

  const BASE_REQUEST: Request = {
    network: NETWORK_ID,
    chainId: CHAIN_ID,
    from: ZERO_ADDRESS,
    onBehalfOf: ZERO_ADDRESS,
    roles: BYTES_32_MID,
    to: ZERO_ADDRESS,
    value: 0n,
    gas: 0n,
    nonce: 0n,
    data: '0x00',
    validUntilTime: 0n
  }

  async function deployForwarder(forwarderRoles = ALL_ROLES) {
    const [deployer, signatory, relayer, genesisKey] = await ethers.getSigners();
    const BubbleForwarder = await ethers.getContractFactory("BubbleForwarder", deployer);
    const NonceRegistry = await ethers.getContractFactory("NonceRegistry", deployer);
    const nonceRegistry = await NonceRegistry.deploy();
    const forwarder = await BubbleForwarder.deploy(NETWORK_ID, nonceRegistry.address, forwarderRoles);
    const request = {...BASE_REQUEST};
    request.from = signatory.address;
    return {request, forwarder, deployer, signatory, relayer, genesisKey};
  }

  async function deployRecipient(request: Request, forwarderAddress: Address, func: string | RawFunctionData, params: any[] = []) {
    const [deployer] = await ethers.getSigners();
    const Recipient = await ethers.getContractFactory("BasicERC2771Recipient", deployer);
    const recipient = await Recipient.deploy(forwarderAddress);
    request.to = recipient.address;
    request.data = typeof func === "string" ? Recipient.interface.encodeFunctionData(func, params) : func.rawData;
    request.gas = BigInt(1e7);
    return recipient;
  }

  async function deployPersona(wallet: SignerWithAddress, adminProxies: Address[] = []) {
    const Persona = await ethers.getContractFactory("BubblePersona", wallet);
    return await Persona.deploy(address(0), adminProxies);
  }

  describe("signature verification", () => {

    it('succeeds when using the BASE_REQUEST', async () => {
      let {request, forwarder, signatory, relayer} = await deployForwarder();
      const signature = await signRequest(request, signatory);
      await expect(forwarder.connect(relayer).execute(request, signature))
      .to.not.be.revertedWith("FWD: signature mismatch");
    });

    it('fails with a signature mismatch error if the network id is invalid', async () => {
      let {request, forwarder, signatory, relayer} = await deployForwarder();
      request.network = NETWORK_ID + BigInt(1);
      const signature = await signRequest(request, signatory);
      await expect(forwarder.connect(relayer).execute(request, signature))
      .to.be.revertedWith("FWD: signature mismatch");
    });

    it('fails with a signature mismatch error if the chain id is invalid', async () => {
      let {request, forwarder, signatory, relayer} = await deployForwarder();
      request.chainId = CHAIN_ID + BigInt(1);
      const signature = await signRequest(request, signatory);
      await expect(forwarder.connect(relayer).execute(request, signature))
      .to.be.revertedWith("FWD: signature mismatch");
    });

    it('fails with a signature mismatch error if the from field does not match the signatory', async () => {
      let {request, forwarder, signatory, relayer} = await deployForwarder();
      request.from = relayer.address;
      const signature = await signRequest(request, signatory);
      await expect(forwarder.connect(relayer).execute(request, signature))
      .to.be.revertedWith("FWD: signature mismatch");
    });

    it('fails with a signature mismatch error if the network field in the request is different from that signed', async () => {
      let {request, forwarder, signatory, relayer} = await deployForwarder();
      request.network = 0n;
      const signature = await signRequest(request, signatory);
      request.network = NETWORK_ID;
      await expect(forwarder.connect(relayer).execute(request, signature))
      .to.be.revertedWith("FWD: signature mismatch");
    });

    it('fails with a signature mismatch error if the chainId field in the request is different from that signed', async () => {
      let {request, forwarder, signatory, relayer} = await deployForwarder();
      request.chainId = 0n;
      const signature = await signRequest(request, signatory);
      request.chainId = CHAIN_ID;
      await expect(forwarder.connect(relayer).execute(request, signature))
      .to.be.revertedWith("FWD: signature mismatch");
    });

    it('fails with a signature mismatch error if the from field in the request is different from that signed', async () => {
      let {request, forwarder, signatory, relayer} = await deployForwarder();
      const signature = await signRequest(request, signatory);
      request.from = relayer.address;
      await expect(forwarder.connect(relayer).execute(request, signature))
      .to.be.revertedWith("FWD: signature mismatch");
    });

    it('fails with a signature mismatch error if the onBehalfOf field in the request is different from that signed', async () => {
      let {request, forwarder, signatory, relayer} = await deployForwarder();
      const signature = await signRequest(request, signatory);
      request.onBehalfOf = address(1);
      await expect(forwarder.connect(relayer).execute(request, signature))
      .to.be.revertedWith("FWD: signature mismatch");
    });

    it('fails with a signature mismatch error if the roles field in the request is different from that signed', async () => {
      let {request, forwarder, signatory, relayer} = await deployForwarder();
      const signature = await signRequest(request, signatory);
      request.roles = 1n;
      await expect(forwarder.connect(relayer).execute(request, signature))
      .to.be.revertedWith("FWD: signature mismatch");
    });

    it('fails with a signature mismatch error if the to field in the request is different from that signed', async () => {
      let {request, forwarder, signatory, relayer} = await deployForwarder();
      const signature = await signRequest(request, signatory);
      request.to = address(1);
      await expect(forwarder.connect(relayer).execute(request, signature))
      .to.be.revertedWith("FWD: signature mismatch");
    });

    it('fails with a signature mismatch error if the value field in the request is different from that signed', async () => {
      let {request, forwarder, signatory, relayer} = await deployForwarder();
      const signature = await signRequest(request, signatory);
      request.value = 1n;
      await expect(forwarder.connect(relayer).execute(request, signature))
      .to.be.revertedWith("FWD: signature mismatch");
    });

    it('fails with a signature mismatch error if the gas field in the request is different from that signed', async () => {
      let {request, forwarder, signatory, relayer} = await deployForwarder();
      const signature = await signRequest(request, signatory);
      request.gas = 1n;
      await expect(forwarder.connect(relayer).execute(request, signature))
      .to.be.revertedWith("FWD: signature mismatch");
    });

    it('fails with a signature mismatch error if the nonce field in the request is different from that signed', async () => {
      let {request, forwarder, signatory, relayer} = await deployForwarder();
      const signature = await signRequest(request, signatory);
      request.nonce = 1n;
      await expect(forwarder.connect(relayer).execute(request, signature))
      .to.be.revertedWith("FWD: signature mismatch");
    });

    it('fails with a signature mismatch error if the data field in the request is different from that signed', async () => {
      let {request, forwarder, signatory, relayer} = await deployForwarder();
      const signature = await signRequest(request, signatory);
      request.data = "0x0102";
      await expect(forwarder.connect(relayer).execute(request, signature))
      .to.be.revertedWith("FWD: signature mismatch");
    });

    it('fails with a signature mismatch error if the validUntilTime field in the request is different from that signed', async () => {
      let {request, forwarder, signatory, relayer} = await deployForwarder();
      const signature = await signRequest(request, signatory);
      request.validUntilTime = 1n;
      await expect(forwarder.connect(relayer).execute(request, signature))
      .to.be.revertedWith("FWD: signature mismatch");
    });

  });

  describe("expiry time", () => {

    let baseBlockTimestamp: number  = 0;
    
    async function runExpiryTest(validUntilTime: number, blockTime: number) {
      if (!baseBlockTimestamp) baseBlockTimestamp = (await ethers.provider.getBlock('latest')).timestamp;
      let {request, forwarder, signatory, relayer} = await deployForwarder();
      request.validUntilTime = BigInt(baseBlockTimestamp+validUntilTime);
      await hardhat.network.provider.send("evm_setNextBlockTimestamp", [baseBlockTimestamp+blockTime]);
      const signature = await signRequest(request, signatory);
      return forwarder.connect(relayer).execute(request, signature);
    }

    it('succeeds if validUntilTime > block time', async () => {
      await expect(runExpiryTest(2001, 2000))
      .to.not.be.revertedWith("FWD: request expired");
    });

    it('succeeds if validUntilTime = block time', async () => {
      await expect(runExpiryTest(3000, 3000))
      .to.not.be.revertedWith("FWD: request expired");
    });

    it('fails with an expired error if validUntilTime < block time', async () => {
      await expect(runExpiryTest(3999, 4000))
      .to.be.revertedWith("FWD: request expired");
    });

  });

  describe("invalid request", () => {

    it('fails with a gas error if it has insufficient gas', async () => {
      let {request, forwarder, signatory, relayer} = await deployForwarder();
      request.gas = BigInt("0x1122334455667788");
      const signature = await signRequest(request, signatory);
      await expect(forwarder.connect(relayer).execute(request, signature))
      .to.be.revertedWith("FWD: insufficient gas");
    });

    it('fails with a "contract does not exist" error if request.to is not a contract', async () => {
      let {request, forwarder, signatory, relayer} = await deployForwarder();
      request.to = ZERO_ADDRESS;
      const signature = await signRequest(request, signatory);
      await expect(forwarder.connect(relayer).execute(request, signature))
      .to.be.revertedWith("FWD: contract does not exist");
    });

  });

  
  describe("valid request", () => {

    const bytes32 = "0x0102030405060708091011121314151617181920212223242526272829303132";
    const bytes = bytes32+bytes32.substring(2)+bytes32.substring(2);

    async function runRecipientFunctionCallTest(func: string | RawFunctionData, expectedFunc: string, params: any[] = [], roles: BigInt = 0n) {
      let {request, forwarder, signatory, relayer} = await deployForwarder();
      request.roles = roles;
      const recipient = await deployRecipient(request, forwarder.address, func, params);
      const signature = await signRequest(request, signatory);
      await expect(forwarder.connect(relayer).execute(request, signature))
      .to.not.be.reverted;
      expect(await recipient.lastFunc()).to.equal(expectedFunc);
      expect(await recipient.lastSender()).to.equal(signatory.address);
      expect(await recipient.lastRoles()).to.equal(ALL_ROLES); // non-bubble id signatories are assumed to have the provider permitted roles
      if (params.length >= 1 ) expect(await recipient.p1()).to.equal(params[0]);
      if (params.length >= 2 ) expect(await recipient.p2()).to.equal(params[1]);
      if (params.length >= 3 ) expect(await recipient.p3()).to.equal(params[2]);
      if (params.length >= 4 ) throw new Error("runRecipientFunctionCallTest does not support more than 3 params");
    }

    it('calls the fallback function if the requested function does not exist', async () => {
      await runRecipientFunctionCallTest({rawData: hardhat.web3.eth.abi.encodeFunctionSignature('nonExistentFunc()')}, "fallback");
    });

    it('gives the signatory as the sender and the correct roles when calling an external function', async () => {
      await runRecipientFunctionCallTest("externalFunc", "externalFunc");
    });

    it('gives the signatory as the sender and the correct roles when calling a public function', async () => {
      await runRecipientFunctionCallTest("publicFunc", "publicFunc");
    });

    it('generating function signature using web3 encodeFunctionSignature works', async () => {
      await runRecipientFunctionCallTest({rawData: hardhat.web3.eth.abi.encodeFunctionSignature('externalFunc()')}, "externalFunc");
    });

    it('calls the fallback function when calling an internal function', async () => {
      const funcSignature = hardhat.web3.eth.abi.encodeFunctionSignature('internalFunc()');
      await runRecipientFunctionCallTest({rawData: funcSignature}, "fallback");
    });

    it('calls the fallback function when calling a private function', async () => {
      const funcSignature = hardhat.web3.eth.abi.encodeFunctionSignature('privateFunc()');
      await runRecipientFunctionCallTest({rawData: funcSignature}, "fallback");
    });

    it('gives the signatory as the sender and the correct roles when calling a function with 1 parameter', async () => {
      await runRecipientFunctionCallTest("funcWithOneParam", "funcWithOneParam", [address(2)], 1n);
    });

    it('gives the signatory as the sender and the correct roles when calling a function with 2 parameters', async () => {
      await runRecipientFunctionCallTest("funcWithTwoParams", "funcWithTwoParams", [address(2), bytes32], BYTES_32_MAX);
    });

    it('gives the signatory as the sender and the correct roles when calling a function with 3 parameters', async () => {
      await runRecipientFunctionCallTest("funcWithManyParams", "funcWithManyParams", [address(2), bytes32, bytes], BigInt(bytes32));
    });

    it('reverts with the expected message when calling a function that reverts', async () => {
      let {request, forwarder, signatory, relayer} = await deployForwarder();
      const recipient = await deployRecipient(request, forwarder.address, "funcThatReverts");
      const signature = await signRequest(request, signatory);
      await expect(forwarder.connect(relayer).execute(request, signature))
      .to.be.revertedWith('funcThatReverts is reverting');
      expect(await recipient.lastFunc()).to.equal('');
      expect(await recipient.lastSender()).to.equal(address(0));
      expect(await recipient.lastRoles()).to.equal(0n);
    });

  });

  describe("valid request using Bubble ID", () => {

    async function setupBubbleIdTest(proxyRoles: bigint, requestRoles: bigint) {
      let {request, forwarder, signatory, deployer, relayer, genesisKey} = await deployForwarder();
      let persona = await deployPersona(genesisKey);
      if (proxyRoles !== 0n) await expect(persona.registerProxy(signatory.address, proxyRoles)).to.not.be.reverted;
      request.onBehalfOf = persona.address;
      request.roles = requestRoles;
      const recipient = await deployRecipient(request, forwarder.address, "externalFunc");
      return {request, forwarder, deployer, signatory, relayer, genesisKey, recipient, persona};
    }

    it('passes the bubble id as the sender address', async () => {
      let {request, forwarder, recipient, persona, signatory, relayer} = await setupBubbleIdTest(ADMIN_ROLE, 1n);
      const signature = await signRequest(request, signatory);
      await expect(forwarder.connect(relayer).execute(request, signature))
      .to.not.be.reverted;
      expect(await recipient.lastSender()).to.equal(persona.address);
      expect(await recipient.lastRoles()).to.equal(request.roles);
    });

    it('succeeds and passes the bubble id and correct roles if the signatory is permitted to act under a specific role', async () => {
      let {request, forwarder, recipient, persona, signatory, relayer} = await setupBubbleIdTest(1n, 1n);
      const signature = await signRequest(request, signatory);
      await expect(forwarder.connect(relayer).execute(request, signature))
      .to.not.be.reverted;
      expect(await recipient.lastSender()).to.equal(persona.address);
      expect(await recipient.lastRoles()).to.equal(1n);
    });

    it('reverts with a denied error if the signatory is not permitted to act as the persona', async () => {
      let {request, forwarder, signatory, relayer} = await setupBubbleIdTest(0n, 1n);
      const signature = await signRequest(request, signatory);
      await expect(forwarder.connect(relayer).execute(request, signature))
      .to.be.revertedWith("FWD: roles denied");
    });

    it('reverts with a denied error if the signatory is not permitted to act under a specific role', async () => {
      let {request, forwarder, signatory, relayer} = await setupBubbleIdTest(ALL_ROLES - ADMIN_ROLE - 1n, 1n);
      const signature = await signRequest(request, signatory);
      await expect(forwarder.connect(relayer).execute(request, signature))
      .to.be.revertedWith("FWD: roles denied");
    });

  });

  describe("forwarder permitted roles", () => {

    async function setupPermittedRolesTest(forwarderRoles: bigint, proxyRoles: bigint, requestRoles: bigint) {
      let {request, forwarder, signatory, deployer, relayer, genesisKey} = await deployForwarder(forwarderRoles);
      let persona = await deployPersona(genesisKey, []);
      if (proxyRoles !== 0n) await expect(persona.registerProxy(signatory.address, proxyRoles)).to.not.be.reverted;
      request.onBehalfOf = persona.address;
      request.roles = requestRoles;
      const recipient = await deployRecipient(request, forwarder.address, "externalFunc");
      return {request, forwarder, deployer, signatory, relayer, genesisKey, recipient, persona};
    }
  
    it('filters (bitwise AND) roles by the permitted roles (signatory and request with ALL_ROLES permissions)', async () => {
      let {request, forwarder, recipient, persona, signatory, relayer} = await setupPermittedRolesTest(BYTES_32_MID, ALL_ROLES, ALL_ROLES);
      const signature = await signRequest(request, signatory);
      await expect(forwarder.connect(relayer).execute(request, signature))
      .to.not.be.reverted;
      expect(await recipient.lastSender()).to.equal(persona.address);
      expect(await recipient.lastRoles()).to.equal(BYTES_32_MID);
    });
  
    it('reverts with permission denied error when signatory and request have permissions different to the forwarder permissions', async () => {
      let {request, forwarder, signatory, relayer} = await setupPermittedRolesTest(5n, ALL_ROLES - ADMIN_ROLE - 5n, ALL_ROLES - ADMIN_ROLE - 5n);
      const signature = await signRequest(request, signatory);
      await expect(forwarder.connect(relayer).execute(request, signature))
      .to.be.revertedWith("FWD: roles denied");
    });
  
    it('results in the forwarder permissions when the request is NOT on behalf of a bubble id', async () => {
      let {request, forwarder, recipient, persona, signatory, relayer} = await setupPermittedRolesTest(BYTES_32_MID, 0n, 1n);
      request.onBehalfOf = address(0);
      const signature = await signRequest(request, signatory);
      await expect(forwarder.connect(relayer).execute(request, signature))
      .to.not.be.reverted;
      expect(await recipient.lastSender()).to.equal(signatory.address);
      expect(await recipient.lastRoles()).to.equal(BYTES_32_MID);
    });
  
  });
  
});


async function signRequest(request: Request, wallet: SignerWithAddress) {
  return signPacket(constructPacket(request), wallet);
}

async function signPacket(packet: Uint8Array, wallet: SignerWithAddress) {
  const packetHash = ethers.utils.keccak256(packet);
  // const signature = await wallet.signMessage(packetHash);
  // console.log(ethers.utils.hexlify(packet));
  // console.log("packetHash:", packetHash);
  // console.log("signatory:", wallet.address);
  // console.log("signature:", signature);
  return await wallet.signMessage(ethers.utils.arrayify(packetHash));
}

function constructPacket(request: Request) {
  return encodePacked(
    {type: "uint256", value: request.network},
    {type: "uint256", value: request.chainId},
    {type: "address", value: request.from},
    {type: "address", value: request.onBehalfOf},
    {type: "uint256", value: request.roles},
    {type: "address", value: request.to},
    {type: "uint256", value: request.value},
    {type: "uint256", value: request.gas},
    {type: "uint256", value: request.nonce},
    {type: "hex256", value: ethers.utils.keccak256(request.data)},
    {type: "uint256", value: request.validUntilTime}
  )
}
