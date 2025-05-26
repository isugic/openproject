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

RSpec.describe EnterpriseToken do
  before do
    described_class.clear_current_tokens_cache

    # Calls are mocked in mock_token_object for enterprise tokens created by
    # tests. This line is to call normal implementation when not mocked.
    allow(OpenProject::Token).to receive(:import).and_call_original
  end

  def create_enterprise_token(encoded_token_name, **attributes)
    mock_token_object(encoded_token_name, **attributes)
    enterprise_token = described_class.new(encoded_token: encoded_token_name)
    enterprise_token.save!(validate: false)
    enterprise_token
  end

  def mock_token_object(encoded_token_name, **attributes)
    token = OpenProject::Token.new(domain: Setting.host_name,
                                   expires_at: 1.year.from_now,
                                   **attributes)
    allow(OpenProject::Token)
      .to receive(:import).with(encoded_token_name)
                          .and_return(token)
    token
  end

  describe ".active?" do
    context "without any tokens" do
      it "returns false" do
        expect(described_class.active?).to be(false)
      end
    end

    context "with a non expired token" do
      before do
        create_enterprise_token("an_non_expired_token", expires_at: 1.year.from_now)
      end

      it "returns true" do
        expect(described_class.active?).to be(true)
      end
    end

    context "with an expired token" do
      before do
        create_enterprise_token(subject.encoded_token, expires_at: Date.yesterday)
      end

      it "returns false" do
        expect(described_class.active?).to be(false)
      end
    end

    context "with two tokens: one expired and one active" do
      before do
        # expired token
        create_enterprise_token("an_expired_token", expires_at: Date.yesterday)

        # active token
        create_enterprise_token("an_active_token", expires_at: 1.year.from_now)
      end

      it "returns true" do
        expect(described_class.active?).to be(true)
      end
    end
  end

  describe ".hide_banners?" do
    context "when ee_hide_banners is true",
            with_config: { ee_hide_banners: true } do
      it "returns true" do
        expect(described_class).to be_hide_banners
      end
    end

    context "when ee_hide_banners is false",
            with_config: { ee_hide_banners: false } do
      it "returns false" do
        expect(described_class).not_to be_hide_banners
      end
    end
  end

  describe ".banner_type_for" do
    before do
      allow(described_class).to receive(:allows_to?).with(:active_feature).and_return(true)
      allow(described_class).to receive(:allows_to?).with(:inactive_feature).and_return(false)
    end

    context "without an EnterpriseToken" do
      before do
        allow(described_class).to receive(:active?).and_return(false)
      end

      it "returns :no_token" do
        expect(described_class.banner_type_for(feature: :active_feature)).to eq(:no_token)
      end
    end

    context "with a feature that is included in the EnterpriseToken" do
      before do
        allow(described_class).to receive(:active?).and_return(true)
      end

      it "returns nil" do
        expect(described_class.banner_type_for(feature: :active_feature)).to be_nil
      end
    end

    context "with a feature that is not included in the EnterpriseToken" do
      before do
        allow(described_class).to receive(:active?).and_return(true)
      end

      it "returns :upsell" do
        expect(described_class.banner_type_for(feature: :inactive_feature)).to eq(:upsell)
      end
    end
  end

  context "with an existing token" do
    context "when inner token is active" do
      subject! do
        mock_token_object(
          "an_active_token_object",
          subscriber: "foo",
          mail: "bar@example.com",
          starts_at: Date.current,
          issued_at: Date.current,
          expires_at: nil,
          restrictions: { foo: :bar }
        )
        described_class.create!(encoded_token: "an_active_token_object")
      end

      it "is returned by .active_tokens" do
        expect(described_class.count).to eq(1)
        expect(described_class.active_tokens).to eq([subject])
        active_token = described_class.active_tokens.first
        expect(active_token.encoded_token).to eq("an_active_token_object")

        # Deleting it updates the active tokens list
        active_token.destroy!

        expect(described_class.count).to eq(0)
        expect(described_class.active_tokens).to be_empty
      end

      it "delegates calls to the inner token object" do
        expect(subject.subscriber).to eq("foo")
        expect(subject.mail).to eq("bar@example.com")
        expect(subject.starts_at).to eq(Date.current)
        expect(subject.issued_at).to eq(Date.current)
        expect(subject.expires_at).to be_nil
        expect(subject.restrictions).to eq(foo: :bar)
      end

      describe "#allows_to?" do
        let(:service_double) { Authorization::EnterpriseService.new(subject) }

        before do
          allow(Authorization::EnterpriseService)
            .to receive(:new)
            .with(subject)
            .and_return(service_double)
        end

        it "forwards to EnterpriseTokenService for checks" do
          allow(service_double)
            .to receive(:call)
            .with(:forbidden_action)
            .and_return ServiceResult.success(result: false)
          allow(service_double)
            .to receive(:call)
            .with(:allowed_action)
            .and_return ServiceResult.success(result: true)

          expect(described_class.allows_to?(:forbidden_action)).to be false
          expect(described_class.allows_to?(:allowed_action)).to be true
        end
      end
    end

    context "when updated with an invalid token" do
      subject! { create_enterprise_token("an_active_token_object", expires_at: 1.year.from_now) }

      it "fails validations" do
        expect { subject.encoded_token = "bar" }
          .to change(subject, :valid?).from(true).to(false)
      end
    end
  end

  describe ".all_tokens" do
    it "returns all tokens, ordered from oldest expiration date to latest (non expiring ones are last)" do
      create_enterprise_token("a_token_expired_recently", expires_at: Date.yesterday)
      create_enterprise_token("a_token_expiring_soon", expires_at: Date.tomorrow)
      create_enterprise_token("a_token_without_an_expiration_date", expires_at: nil)
      create_enterprise_token("a_token_expired_since_one_year", expires_at: Date.current - 1.year)
      create_enterprise_token("a_token_expiring_in_one_year", expires_at: Date.current + 1.year)

      expect(described_class.all_tokens.map(&:encoded_token))
        .to eq(%w[
                 a_token_expired_since_one_year
                 a_token_expired_recently
                 a_token_expiring_soon
                 a_token_expiring_in_one_year
                 a_token_without_an_expiration_date
               ])
    end

    it "sorts by token start date if multiple tokens have the same expiration date" do
      create_enterprise_token("a_token_started_one_week_ago", starts_at: Date.current - 1.week, expires_at: Date.current + 1.year)
      create_enterprise_token("a_token_starting_in_one_week", starts_at: Date.current + 1.week, expires_at: Date.current + 1.year)
      create_enterprise_token("a_token_started_one_year_ago", starts_at: Date.current - 1.year, expires_at: Date.current + 1.year)
      create_enterprise_token("a_non_expiring_token_starting_in_one_month", starts_at: Date.current + 1.month, expires_at: nil)
      create_enterprise_token("a_non_expiring_token_started_today", starts_at: Date.current, expires_at: nil)
      create_enterprise_token("a_non_expiring_token_started_one_month_ago", starts_at: Date.current - 1.month, expires_at: nil)

      expect(described_class.all_tokens.map(&:encoded_token))
        .to eq(%w[
                 a_token_started_one_year_ago
                 a_token_started_one_week_ago
                 a_token_starting_in_one_week
                 a_non_expiring_token_started_one_month_ago
                 a_non_expiring_token_started_today
                 a_non_expiring_token_starting_in_one_month
               ])
    end
  end

  describe ".active_tokens" do
    context "with no tokens" do
      it "returns an empty array" do
        expect(described_class.active_tokens).to be_empty
      end
    end

    context "with an active token" do
      let!(:active_token) { create_enterprise_token("an_active_token", expires_at: 1.year.from_now) }

      it "returns the active token" do
        expect(described_class.active_tokens).to eq([active_token])
      end
    end

    context "with expired and invalid tokens" do
      let!(:expired_token) { create_enterprise_token("an_expired_token", expires_at: Date.yesterday) }
      let!(:invalid_token) { create_enterprise_token("an_invalid_token_with_wrong_domain", domain: "wrong.domain") }

      it "returns an empty array" do
        expect(described_class.active_tokens).to be_empty
      end
    end
  end

  context "when Configuration file has `ee_hide_banners` set to false",
          with_config: { ee_hide_banners: false } do
    it "shows banners promoting Enterprise plans" do
      expect(described_class).not_to be_hide_banners
    end
  end
end
