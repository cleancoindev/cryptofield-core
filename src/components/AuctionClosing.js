import React, { Component } from "react";
import SaleAuction from "./../../build/contracts/SaleAuction.json";

export default class AuctionClosing extends Component {
  constructor(props) {
    super(props);

    this.state = {
      auctionId: "",
      instance: null
    }

    this.handleSubmit = this.handleSubmit.bind(this);
    this.handleChange = this.handleChange.bind(this);
  }

  async componentDidMount() {
    let contract = require("truffle-contract");
    let SaleAuctionContract = await contract(SaleAuction);

    await SaleAuctionContract.setProvider(this.props.web3.currentProvider);

    let instance = await SaleAuctionContract.deployed();

    await this.setState({ instance: instance })
  }

  async handleSubmit(e) {
    await e.preventDefault();
    let accounts = await this.props.web3.eth.getAccounts();
    await this.state.instance.closeAuction(this.state.auctionId, { from: accounts[0], gas: 100000 });
  }

  handleChange(e) {
    this.setState({ [e.target.name]: e.target.value })
  }

  render() {
    return (
      <div className>
        <form onSubmit={this.handleSubmit}>
          <div className="grid-x grid-margin-x">
            <div className="medium-6 medium-offset-3 cell">
              <label>
                Auction ID:

                <input
                  onChange={this.handleChange}
                  type="number"
                  name="auctionId"
                  value={this.state.auctionId}
                  min={0}
                />
              </label>
            </div>

            <div className="text-center cell">
              <input type="submit" value="Close auction" className="button success" />
            </div>
          </div>
        </form>
      </div>
    )
  }
}