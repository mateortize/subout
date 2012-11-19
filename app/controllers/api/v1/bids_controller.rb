class Api::V1::BidsController < Api::V1::BaseController
  def index
    respond_with current_company.bids
  end

  def create
    bid = opportunity.bids.build(params[:bid])
    bid.bidder = current_company
    bid.save

    respond_with(bid.opportunity, bid)
  end

  private

  helper_method :opportunity
  def opportunity
    @opportunity ||= Opportunity.find(params[:opportunity_id])
  end
end
