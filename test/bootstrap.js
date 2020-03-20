const {
  expect
} = require('chai');
const chai = require("chai");
const chaiAsPromised = require("chai-as-promised");

chai.use(chaiAsPromised);
chai.should();

global.window = {};
global.navigator = {};

