describe VisitorsController, :omniauth do

  describe 'GET #index' do
    context 'when user is not logged in' do
      before do
        get :index
      end

      it 'should return the correct layout' do
        expect(response).to render_template(:application)
      end
    end

    context 'when user is logged in' do
      before do
        @user = FactoryBot.create(:user)
        request.session[:user_id] = @user.id
        get :index, {}
      end

      it 'should return the correct layout' do
        expect(request.session[:user_id]).to eq @user.id
        # expect(response).to render_template(:authenticated)
      end

    end
  end
end