# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require "spec_helper"
require "services/base_services/behaves_like_update_service"

RSpec.describe ScimClients::UpdateService, type: :model do
  subject { instance.call(params) }

  let(:user) { build_stubbed(:user) }
  let(:instance) { described_class.new(user:, model: scim_client) }
  let(:params) do
    {
      name: "The client name",
      auth_provider_id: auth_provider.id,
      authentication_method: "sso",
      jwt_sub: "123-456"
    }
  end
  let(:auth_provider) { create(:oidc_provider, slug: "provider-slug") }
  let(:scim_client) do
    create(:scim_client, service_account: create(:service_account), oauth_application: create(:oauth_application))
  end

  it_behaves_like "BaseServices update service"

  it "update the service account", :aggregate_failures do
    expect { subject }.to change { scim_client.reload.service_account.name }.to("The client name")
  end

  context "when using sso as authentication_method" do
    it "sets the identity_url of the service account" do
      expect { subject }.to change { scim_client.reload.service_account.identity_url }.to("provider-slug:123-456")
    end

    it "removes an OAuth application if SSO" do
      expect { subject }.to change { scim_client.reload.oauth_application }.to(nil)
    end
  end

  context "when using oauth2 as authentication_method" do
    let(:params) do
      {
        name: "The client name",
        auth_provider_id: auth_provider.id,
        authentication_method: "oauth2"
      }
    end

    it "unsets the identity_url of the service account" do
      client = subject.result
      expect(client.service_account.identity_url).to be_nil
    end

    it "keeps the existing oauth2_application" do
      expect { subject }.not_to change { scim_client.reload.oauth_application }
    end
  end

  context "when there is no service account associated" do
    let(:scim_client) do
      create(:scim_client, oauth_application: create(:oauth_application))
    end

    it "creates one", :aggregate_failures do
      subject
      scim_client.reload

      expect(scim_client.service_account).to be_present
      expect(scim_client.service_account&.name).to eq("The client name")
    end
  end
end
