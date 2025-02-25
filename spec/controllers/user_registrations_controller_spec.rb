require 'spec_helper'

describe UserRegistrationsController, type: :controller do
  include OpenFoodNetwork::EmailHelper

  before(:all) do
    setup_email
  end

  before do
    @request.env["devise.mapping"] = Devise.mappings[:spree_user]
  end

  describe "via ajax" do
    render_views

    let(:user_params) do
      {
        email: "test@test.com",
        password: "testy123",
        password_confirmation: "testy123"
      }
    end

    it "returns validation errors" do
      xhr :post, :create, spree_user: {}, use_route: :spree
      expect(response.status).to eq(401)
      json = JSON.parse(response.body)
      expect(json).to eq("email" => ["can't be blank"], "password" => ["can't be blank"])
    end

    it "returns error when emailing fails" do
      allow(Spree::UserMailer).to receive(:confirmation_instructions).and_raise("Some error")
      expect(OpenFoodNetwork::ErrorLogger).to receive(:notify)

      xhr :post, :create, spree_user: user_params, use_route: :spree

      expect(response.status).to eq(401)
      json = JSON.parse(response.body)
      expect(json).to eq("message" => I18n.t('devise.user_registrations.spree_user.unknown_error'))
    end

    it "returns 200 when registration succeeds" do
      xhr :post, :create, spree_user: user_params, use_route: :spree
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json).to eq("email" => "test@test.com")
      expect(controller.spree_current_user).to be_nil
    end

    it "sets user.locale from cookie on create" do
      original_locale_cookie = cookies[:locale]
      cookies[:locale] = "pt"

      xhr :post, :create, spree_user: user_params, use_route: :spree

      expect(assigns[:user].locale).to eq("pt")
      cookies[:locale] = original_locale_cookie
    end
  end
end
