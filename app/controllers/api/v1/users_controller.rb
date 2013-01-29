class Api::V1::UsersController < Api::V1::BaseController
  def update
    current_user.update_with_password(params[:user])
    respond_with_namespace(current_user)
  end

  def show
    user = User.find(params[:id])
    respond_with_namespace(user)
  end
end
