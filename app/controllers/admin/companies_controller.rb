class Admin::CompaniesController < Admin::BaseController
  before_filter :load_company, only: [:edit, :update, :connect_subscription, :cancel_subscription, :reactivate_subscription, :add_as_a_favorite, :lock_account, :unlock_account, :change_emails, :change_password, :change_mode]

  def index
    @sort_by = params[:sort_by] || "created_at"
    @sort_direction = params[:sort_direction] || "desc"
    @companies = Company.sort(@sort_by, @sort_direction).includes(:users)
    @companies = @companies.full_text_search(params[:search]) unless params[:search].blank?
    @companies = @companies.page(params[:page]).per(20)

    respond_to do |format|
      format.html
      format.csv { send_data Company.sort(@sort_by, @sort_direction).includes(:users).to_csv }
    end
  end

  def edit
    @subscription = @company.created_from_subscription
    if !@subscription or !@subscription.exists_on_chargify?
      flash.now[:error] = "Subscription is not found on chargify."
    end
  end

  def update
    @company.update_attributes(params[:company])

    redirect_to edit_admin_company_path(@company), notice: 'Company is updated.'
  end

  def change_emails
    @company.change_emails!(params[:email])
    redirect_to edit_admin_company_path(@company), notice: 'All emails were updated successfully.'
  end

  def change_mode 
    @company.update_attribute(:mode, params[:mode])
    redirect_to edit_admin_company_path(@company), notice: 'Company mode were updated successfully.'
  end

  def change_password
    user = @company.users.find(params[:user_id])
    if user.update_attributes(params[:user])
      redirect_to edit_admin_company_path(@company), notice: 'Password were updated successfully.'
    else
      flash.now[:error] = user.errors.full_messages.join("<br/>")
      render :edit 
    end
  end

  def lock_account
    if subscription = @company.created_from_subscription
      subscription.cancel!
    end
    @company.lock_access!
    redirect_to edit_admin_company_path(@company), notice: "This account is locked."
  end

  def unlock_account
    if subscription = @company.created_from_subscription
      subscription.reactivate!
    end
    @company.unlock_access!
    redirect_to edit_admin_company_path(@company), notice: "This account is unlocked."
  end

  def cancel_subscription
    if subscription = @company.created_from_subscription
      subscription.cancel!
    end
    redirect_to edit_admin_company_path(@company), notice: "This subscription is canceled."
  end

  def reactivate_subscription
    if subscription = @company.created_from_subscription
      subscription.reactivate!
    end
    redirect_to edit_admin_company_path(@company), notice: "This subscription is reactivated."
  end

  def connect_subscription
    if params[:subscription_id].blank?
      flash.now[:error] = "Please input subscription id."
      render :edit
      return
    end

    params[:subscription_id] = params[:subscription_id].strip
    exist_gs = GatewaySubscription.where(subscription_id: params[:subscription_id]).first
    if exist_gs and exist_gs.created_company
      flash.now[:error] = "This subscription is already used in another company."
      render :edit
      return
    end

    if Chargify::Subscription.exists?(params[:subscription_id])
      if exist_gs
        gw_subscription = exist_gs
      else
        subscription = Chargify::Subscription.find(params[:subscription_id])

        customer = subscription.customer

        gw_subscription = GatewaySubscription.create(
          subscription_id: params[:subscription_id],
          customer_id:     customer.id,
          email:           customer.email,
          first_name:      customer.first_name,
          last_name:       customer.last_name,
          organization:    customer.organization,
          product_handle:  subscription.product.handle,
          state:           subscription.state,
        )
      end

      unless @company.created_from_subscription.blank?
        @company.created_from_subscription.destroy
      end

      @company.created_from_subscription = gw_subscription
      @company.set_subscription_info
      @company.save

      gw_subscription.confirm!
      gw_subscription.update_credit_card_expired

      Notifier.delay.updated_product(@company.id)

      redirect_to edit_admin_company_path(@company), notice: "Company has connected with subscription on the chargify."
    else
      flash.now[:error] = "This subscription is no exist on the chargify."
      render :edit
    end
  end

  def add_as_a_favorite
    poster = Company.find(params[:company_id])
    poster.add_favorite_supplier!(@company)
    redirect_to edit_admin_company_path(@company)
  end

  private

  def load_company
    @company = Company.find(params[:id])
  end
end
