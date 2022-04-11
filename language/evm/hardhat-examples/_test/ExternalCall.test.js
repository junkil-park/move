const { BN, constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const { ZERO_ADDRESS } = constants;

const { expect } = require('chai');

const ExternalCall = artifacts.require('ExternalCall');
const FortyTwo = artifacts.require('FortyTwo');
const Revert = artifacts.require('Revert');


contract('ERC1155', function (accounts) {
    const [operator, tokenHolder, tokenBatchHolder, ...otherAccounts] = accounts;

    beforeEach(async function () {
        this.externalCall = await ExternalCall.new();
        this.fortyTwo = await FortyTwo.new();
        this.revert = await Revert.new();
    });

    describe('getFortyTwo', function () {
        it('returns 42', async function () {
            expect(await this.externalCall.getFortyTwo(this.fortyTwo.address)).to.be.bignumber.equal('42');
        });

        // it('revert with a message', async function () {
        //     await expectRevert(
        //         this.externalCall.callRevertWithMessage(this.revert.address, 'error message'),
        //         'error message',
        //     );
        // });
    });
});