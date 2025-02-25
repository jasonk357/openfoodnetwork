require 'spec_helper'

describe Api::TaxonsController do
  render_views

  let(:taxonomy) { create(:taxonomy) }
  let(:taxon) { create(:taxon, name: "Ruby", taxonomy: taxonomy) }
  let(:taxon2) { create(:taxon, name: "Rails", taxonomy: taxonomy) }
  let(:attributes) {
    ["id", "name", "pretty_name", "permalink", "position", "parent_id", "taxonomy_id"]
  }

  before do
    allow(controller).to receive(:spree_current_user) { current_api_user }

    taxon2.children << create(:taxon, name: "3.2.2", taxonomy: taxonomy)
    taxon.children << taxon2
    taxonomy.root.children << taxon
  end

  context "as a normal user" do
    let(:current_api_user) { build(:user) }

    it "gets all taxons for a taxonomy" do
      api_get :index, taxonomy_id: taxonomy.id

      expect(json_response.first['name']).to eq taxon.name
    end

    it "gets all taxons" do
      api_get :index

      expect(json_response.first['name']).to eq taxonomy.root.name
    end

    it "can search for a single taxon" do
      api_get :index, q: { name_cont: "Ruby" }

      expect(json_response.count).to eq(1)
      expect(json_response.first['name']).to eq "Ruby"
    end

    it "gets all taxons in JSTree form" do
      api_get :jstree, taxonomy_id: taxonomy.id, id: taxon.id

      response = json_response.first
      response["data"].should eq(taxon2.name)
      response["attr"].should eq("name" => taxon2.name, "id" => taxon2.id)
      response["state"].should eq("closed")
    end

    it "cannot create a new taxon if not an admin" do
      api_post :create, taxonomy_id: taxonomy.id, taxon: { name: "Location" }

      assert_unauthorized!
    end

    it "cannot update a taxon" do
      api_put :update, taxonomy_id: taxonomy.id,
                       id: taxon.id,
                       taxon: { name: "I hacked your store!" }

      assert_unauthorized!
    end

    it "cannot delete a taxon" do
      api_delete :destroy, taxonomy_id: taxonomy.id, id: taxon.id

      assert_unauthorized!
    end
  end

  context "as an admin" do
    let(:current_api_user) { build(:admin_user) }

    it "can create" do
      api_post :create, taxonomy_id: taxonomy.id, taxon: { name: "Colors" }

      expect(attributes.all? { |a| json_response.include? a }).to be true
      expect(response.status).to eq(201)

      expect(taxonomy.reload.root.children.count).to eq 2

      expect(Spree::Taxon.last.parent_id).to eq taxonomy.root.id
      expect(Spree::Taxon.last.taxonomy_id).to eq taxonomy.id
    end

    it "cannot create a new taxon with invalid attributes" do
      api_post :create, taxonomy_id: taxonomy.id, taxon: {}

      expect(response.status).to eq(422)
      expect(json_response["error"]).to eq("Invalid resource. Please fix errors and try again.")
      errors = json_response["errors"]

      expect(taxonomy.reload.root.children.count).to eq 1
    end

    it "cannot create a new taxon with invalid taxonomy_id" do
      api_post :create, taxonomy_id: 1000, taxon: { name: "Colors" }

      expect(response.status).to eq(422)
      expect(json_response["error"]).to eq("Invalid resource. Please fix errors and try again.")

      errors = json_response["errors"]
      expect(errors["taxonomy_id"]).not_to be_nil
      expect(errors["taxonomy_id"].first).to eq "Invalid taxonomy id."

      expect(taxonomy.reload.root.children.count).to eq 1
    end

    it "can destroy" do
      api_delete :destroy, taxonomy_id: taxonomy.id, id: taxon2.id

      expect(response.status).to eq(204)
    end
  end  
end
