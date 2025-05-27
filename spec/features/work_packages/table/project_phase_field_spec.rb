# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Project phase field in the work package table", :js do
  let(:project_phase_definition) { create(:project_phase_definition, position: 99) }
  let(:project_phase) { create(:project_phase, definition: project_phase_definition) }
  let(:other_project_phase) { create(:project_phase) }
  let(:project_phases) { [project_phase, other_project_phase].compact }
  let(:project) { create(:project_with_types, phases: project_phases) }
  let(:another_project) { create(:project_with_types) }
  let(:all_permissions) do
    %i[
      view_work_packages
      view_work_package_watchers
      edit_work_packages
      add_work_package_watchers
      delete_work_package_watchers
      manage_work_package_relations
      add_work_package_comments
      add_work_packages
      view_time_entries
      view_changesets
      view_file_links
      manage_file_links
      delete_work_packages
      view_project_phases
    ]
  end
  let(:work_package) do
    create(:work_package,
           project:,
           project_phase_definition:,
           subject: "first wp",
           author: current_user)
  end
  let!(:other_wp) do
    create(:work_package,
           project:,
           project_phase_definition: other_project_phase.definition,
           subject: "other wp",
           author: current_user)
  end
  let!(:wp_without_phase) do
    create(:work_package,
           project:,
           subject: "wp without phase",
           author: current_user)
  end
  let!(:wp_from_another_project) do
    create(:work_package,
           project: another_project,
           subject: "wp from another project",
           author: current_user)
  end
  let!(:wp_table) { Pages::WorkPackagesTable.new(work_package.project) }
  let(:sort_criteria) { nil }
  let(:group_by) { nil }
  let(:user) do
    create(:user,
           member_with_permissions: {
             project => all_permissions,
             another_project => all_permissions - [:view_project_phases]
           })
  end
  let!(:query) do
    build(:public_query, user: current_user, project: work_package.project)
  end
  let(:query_columns) { %w(subject project_phase) }

  current_user { user }

  before do
    query.column_names  = query_columns
    query.sort_criteria = sort_criteria if sort_criteria
    query.group_by      = group_by if group_by
    query.filters.clear
    query.show_hierarchies = false
    query.save!

    wp_table.visit_query query
    wp_table.expect_work_package_listed work_package

    wait_for_network_idle
  end

  context "with the feature flag being active", with_flag: { stages_and_gates: true } do
    context "with the phase being active" do
      it "shows the project phase column with the correct phase for the work package" do
        wp_table.expect_work_package_with_attributes(work_package, { projectPhase: project_phase.name })
        wp_table.expect_work_package_with_attributes(other_wp, { projectPhase: other_project_phase.name })
        wp_table.expect_work_package_with_attributes(wp_without_phase, { projectPhase: "-" })
      end

      context "when sorting by project phase ASC" do
        let(:sort_criteria) { [%w[project_phase asc]] }

        it "sorts ASC by phase position" do
          wp_table.expect_work_package_order(other_wp, work_package, wp_without_phase)
        end
      end

      context "when sorting by project phase DESC" do
        let(:sort_criteria) { [%w[project_phase desc]] }

        it "sorts DESC by phase position" do
          wp_table.expect_work_package_order(wp_without_phase, work_package, other_wp)
        end
      end

      context "when editing the value of a project phase cell" do
        it "changes the value" do
          wp_table.update_work_package_attributes(wp_without_phase, projectPhase: project_phase_definition)
          wp_table.expect_work_package_with_attributes(wp_without_phase, { projectPhase: project_phase.name })
        end
      end

      context "when grouping by project phase" do
        let(:group_by) { :project_phase }

        it "groups by project phase" do
          wp_table.expect_groups({
                                   project_phase.name => 1,
                                   other_project_phase.name => 1,
                                   "-" => 1
                                 })
        end

        it "includes the group icon in the group row header" do
          within("#wp-table-rowgroup-0") do
            expect(page).to have_test_selector("project-phase-icon #{other_project_phase.name}")
          end

          within("#wp-table-rowgroup-1") do
            expect(page).to have_test_selector("project-phase-icon #{project_phase.name}")
          end
        end
      end
    end

    context "with one phase being inactive" do
      let(:other_project_phase) { create(:project_phase, active: false) }

      it "does not show the inactive phase" do
        wp_table.expect_work_package_with_attributes(work_package, { projectPhase: project_phase.name })
        wp_table.expect_work_package_with_attributes(other_wp, { projectPhase: "-" })
        wp_table.expect_work_package_with_attributes(wp_without_phase, { projectPhase: "-" })
      end

      context "when grouping" do
        let(:group_by) { :project_phase }

        it "treats work packages with an inactive project phase like work packages without a project phase" do
          wp_table.expect_groups({
                                   project_phase.name => 1,
                                   "-" => 2
                                 })
        end
      end
    end

    context "without the necessary permissions" do
      let!(:query) { build(:global_query, user: current_user) }

      it "does not render project phases you don't have permission for" do
        # permission given, phase visible:
        wp_table.expect_work_package_with_attributes(work_package, { projectPhase: project_phase_definition.name })

        # permission missing, phase invisible:
        wp_table.expect_work_package_with_attributes(wp_from_another_project, { projectPhase: "" })
      end
    end
  end

  context "with the feature flag being inactive", with_flag: { stages_and_gates: false } do
    let(:query_columns) { %w(subject) }

    it "does not offer to add the column to a query" do
      wp_table.click_setting_item("Insert column")
      wp_table.expect_no_column_add_option("Project phase")
    end
  end
end
