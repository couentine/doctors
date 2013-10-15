require 'spec_helper'

feature "Edit Badge" do
  
  given(:user) { FactoryGirl.create(:user) }
  given(:badge) { FactoryGirl.create(:badge) }

  background(:each) do
    visit new_user_session_path
    fill_in 'user[email]', :with => user.email
    fill_in 'user[password]', :with => 'password'
    click_link_or_button 'Sign in'
    visit edit_badge_path(badge)
  end

  scenario "User updates fields and clicks save" do
    page.fill_in "badge_name", with: "Updated Badge Name"
    page.fill_in "badge_image_url", with: "http://example.com/updated.png"
    page.fill_in "badge_summary", with: "Updated Badge Summary"
    page.fill_in "badge_description", with: "Updated Badge Description"
    click_button "Update Badge"

    # This should take us back to the badge detail with the new values.
    page.should have_selector('h1', text: "Updated Badge Name")
    page.should have_text("Updated Badge Name")
    page.should have_selector("img[src='http://example.com/updated.png']")
    page.should have_text("Updated Badge Summary")
    page.should have_text("Updated Badge Description")
  end

  scenario "User updates fields and clicks cancel" do
    page.fill_in "badge_name", with: "Updated Badge Name"
    page.fill_in "badge_image_url", with: "http://example.com/updated.png"
    page.fill_in "badge_summary", with: "Updated Badge Summary"
    page.fill_in "badge_description", with: "Updated Badge Description"
    click_link "Cancel"

    # This should take us back to the badge detail with unchanged values.
    page.should have_selector('h1', text: badge.name)
    page.should_not have_text("Updated Badge Name")
    page.should_not have_selector("img[src='http://example.com/updated.png']")
    page.should_not have_text("Updated Badge Summary")
    page.should_not have_text("Updated Badge Description")
  end

end
