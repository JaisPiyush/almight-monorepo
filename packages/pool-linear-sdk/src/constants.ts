import { addressRecord, AddressName } from '@almight/address';
import { ethers } from 'ethers';

export const FACTORY_ADDRESS = addressRecord[AddressName.POOL_LINEAR_FACTORY];

export const MINIMUM_LIQUIDITY = ethers.toBigInt('1000');
