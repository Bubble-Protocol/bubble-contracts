// @ts-nocheck

export function address(val) {
  return '0x'+('0000000000000000000000000000000000000000'+val.toString(16)).slice(-40);
}

export const ZERO_ADDRESS = address(0);

//
// String Utils
//

export function textToByteArray(val: string, length: number) {
  const arr = new Uint8Array(length);
  let arrIndex = length - val.length;
  for (let i=0; i<val.length; i++) {
    arr[arrIndex++] = val.charCodeAt(i);
  }
  return arr;
}

export function hexToByteArray(val: string, length: number) {
  if (val.startsWith("0x")) val = val.substr(2);
  const arr = new Uint8Array(length);
  const valArr = Buffer.from(val, 'hex');
  let arrIndex = length - valArr.length;
  for (let i=0; i<valArr.length; i++) {
    arr[arrIndex++] = valArr[i];
  }
  return arr;
}

export function uintToByteArray(val: any, length: number) {
  val = BigInt(val);
  const arr = new Uint8Array(length);
  let i = arr.length-1;
  while (val > 0) {
    arr[i--] = Number((val & BigInt(0xFF)));
    val = val >> BigInt(8);
  }
  return arr;
}

//
// Packet functions
//

const clParamRegex = /[0-9]+$/;

export function encodePacked(...args: any) {
  const packet = new Uint8Array(1024);
  let index = 0;
  args.forEach(arg => {
    const customLengthParam = clParamRegex.test(arg.type);
    const type = customLengthParam ? arg.type.replace(clParamRegex, '') : arg.type;
    let length = customLengthParam ? parseInt(arg.type.substring(arg.type.search(clParamRegex)))/8 : undefined;
    switch (type) {

      case 'string':
        packet.set(textToByteArray(arg.value, arg.value.length), index);
        console.debug(arg, type, index, arg.value.length);
        index += arg.value.length;
        break;
        
      case 'hex':
        if (!customLengthParam) length = arg.value.startsWith('0x') ? arg.value.length/2 - 1 : arg.value.length/2;
        packet.set(hexToByteArray(arg.value, length), index);
        // console.debug(arg, type, index, length);
        index += length;
        break;

      case 'address':
        packet.set(hexToByteArray(arg.value, 20), index);
        // console.debug(arg, type, index, 20);
        index += 20;
        break;

      case 'bool':
        packet.set(uintToByteArray(arg.value ? 1 : 0, 1), index);
        // console.debug(arg, type, index, 1);
        index += 1;
        break;

      case 'uint':
        if (!customLengthParam) length = 32;  // default to uint256
        packet.set(uintToByteArray(arg.value, length), index);
        // console.debug(arg, type, index, length);
        index += length;
        break;

      default:
        throw new Error("invalid type passed to encodePacked: '"+type+"'");
    }
  })
  const finalPacket = packet.slice(0, index);
  return finalPacket;
}


export default {
  address: address,
  ZERO_ADDRESS: ZERO_ADDRESS,
  encodePacked: encodePacked,
  textToByteArray: textToByteArray,
  hexToByteArray: hexToByteArray
}

