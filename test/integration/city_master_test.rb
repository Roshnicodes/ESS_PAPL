require "test_helper"

class CityMasterTest < ActionDispatch::IntegrationTest
  test "PD HR adds / edits / disables a city; only enabled cities are offered in the claim form" do
    hr = user("HR001")
    sign_in hr
    get masters_cities_path
    assert_response :success
    post masters_cities_path, params: { city: { name: "Sehore Town", da_rate: 575, active: "1" } }
    city = City.find_by!(name: "Sehore Town")
    assert_equal 575, city.da_rate
    assert_equal "city_added", city.activity_logs.last.action
    patch masters_city_path(city), params: { city: { da_rate: 590 } }
    assert_equal 590, city.reload.da_rate
    patch toggle_masters_city_path(city)
    follow_redirect!
    refute city.reload.active?

    emp = user("1025")
    emp.update!(l2_manager: nil)
    t = emp.tours.create!(send_now: true, from_date: Date.current - 5, to_date: Date.current - 4,
      tour_visits_attributes: [ { visit_date: Date.current - 5, place: "Sehore", planned_activity: "Mtg" } ])
    t.approve!(by: emp.reporting_manager)
    sign_out hr
    sign_in emp
    get new_tour_claim_path(t)
    assert_no_match "Sehore Town", response.body
    assert_match ">Bhopal<", response.body
  end

  test "employee cannot open the city master" do
    sign_in user("1025")
    get masters_cities_path
    assert_redirected_to root_path
  end

  test "City Excel: download and upload back; rate changed; new city added" do
    sign_in user("HR001")
    get export_masters_cities_path
    assert_response :success
    xlsx = Tempfile.new([ "cities", ".xlsx" ]); xlsx.binmode; xlsx.write(response.body); xlsx.close
    post import_masters_cities_path, params: { file: Rack::Test::UploadedFile.new(xlsx.path, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet") }
    assert_match "0 new cities added, 0 updated", flash[:notice]

    csv = Tempfile.new([ "cities", ".csv" ])
    csv.write("City,DA Rate\nIndore,650\nNew Town X,575\n"); csv.close
    post import_masters_cities_path, params: { file: Rack::Test::UploadedFile.new(csv.path, "text/csv") }
    assert_match "1 new cities added, 1 updated", flash[:notice]
    assert_equal 650, City.find_by!(name: "Indore").da_rate
    assert_equal 575, City.find_by!(name: "New Town X").da_rate
    assert_equal "city_updated", City.find_by!(name: "Indore").activity_logs.last.action
  end
end
