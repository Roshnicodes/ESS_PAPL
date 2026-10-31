# Idempotent seeds: masters for the ESS dropdowns.
# Demo users are for development only (password: Password@123).

ActiveRecord::Base.transaction do
  ho = Location.find_or_create_by!(name: "Head Office") { |l| l.code = "HO" }

  def seed_user(emp_code, attrs)
    User.find_or_initialize_by(emp_code: emp_code).tap do |u|
      u.assign_attributes(attrs)
      u.password = "Password@123" if u.new_record?
      u.save!
    end
  end

  admin   = seed_user("ADMIN",  name: "System Admin",   role: "admin",      designation: "Administrator", location: ho)
  hr      = seed_user("HR001",  name: "PD HR",          role: "pd_hr",      designation: "PD HR",         short_designation: "PD HR", location: ho)
  fin     = seed_user("FIN001", name: "PD Finance",     role: "pd_finance", designation: "PD Finance",    short_designation: "PD FIN", location: ho)
  mis     = seed_user("MIS001", name: "MIS Verifier",   role: "mis",        designation: "MIS Officer",   short_designation: "MIS", location: ho) unless User.where.not(imported_at: nil).exists?
  # Demo employees only until HR uploads the real Employee List (Masters → Employee List → Upload Excel)
  unless User.where.not(imported_at: nil).exists?
    manager = seed_user("AM001",  name: "Amit Verma",   role: "employee",   designation: "Area Manager",  short_designation: "AM", location: ho,
                                  reporting_manager: hr)
    seed_user("1025", name: "Priya Sharma", role: "employee", designation: "Project Associate", level: "L - 5", location: ho,
                      reporting_manager: manager)
  end

  # Mode of Travel master – same names/order as the live ESS dropdowns
  #   Tour Plan:            Personal Two Wheeler … Office Vehicle (incl. NA, Taxi (Out of City))
  #   A. Travel city-city:  Personal Two Wheeler … Office Vehicle (no NA / Taxi (Out of City))
  #   B. Local travel:      Two Wheeler (₹4.25/km), Four Wheeler (₹10/km), Public Transport (KM + total typed)
  [
    # name,                    category,      km,    manual, plan,  city,  local
    [ "Personal Two Wheeler",  "own_vehicle", false, false,  true,  true,  false ],
    [ "Personal Four Wheeler", "own_vehicle", false, false,  true,  true,  false ],
    [ "Train(SL)",             "public",      false, false,  true,  true,  false ],
    [ "Train(3A)",             "public",      false, false,  true,  true,  false ],
    [ "Train(2A)",             "public",      false, false,  true,  true,  false ],
    [ "Train(1A)",             "public",      false, false,  true,  true,  false ],
    [ "Vande Bharat Train",    "public",      false, false,  true,  true,  false ],
    [ "NA",                    "none",        false, false,  true,  false, false ],
    [ "Flight",                "public",      false, false,  true,  true,  false ],
    [ "Bus",                   "public",      false, false,  true,  true,  false ],
    [ "Taxi",                  "public",      false, false,  true,  true,  false ],
    [ "Taxi (Out of City)",    "public",      false, false,  true,  false, false ],
    [ "Office Vehicle",        "office",      false, false,  true,  true,  false ],
    [ "Two Wheeler",           "own_vehicle", true,  false,  false, false, true ],
    [ "Four Wheeler",          "own_vehicle", true,  false,  false, false, true ],
    [ "Public Transport",      "public",      false, true,   false, false, true ]
  ].each_with_index do |(name, cat, km, manual, plan, city, local), i|
    TravelMode.find_or_initialize_by(name: name).tap do |m|
      m.assign_attributes(category: cat, km_based: km, manual_total: manual, for_tour_plan: plan, for_city_travel: city,
                          for_local_travel: local, position: i + 1, created_by: m.created_by || admin)
      m.save!
    end
  end

  TravelMode.where("name ILIKE 'Train(%' OR name = ?", "Vande Bharat Train").update_all(is_train: true)

  # Mandatory mode-specific approvals.  The designation lookup keeps this
  # idempotent after Employee List imports update the people behind the roles.
  coo = User.active.find_by("lower(trim(designation)) = ?", "coo")
  director = User.active.find_by("lower(trim(designation)) = ?", "director")
  routes = {
    "Personal Four Wheeler" => [ coo, director ],
    "Train(3A)" => [ coo ],
    "Train(2A)" => [ coo ],
    "Train(1A)" => [ director ],
    "Flight" => [ director ],
    "Vande Bharat Train" => [ coo ]
  }
  routes.each do |name, approvers|
    next if approvers.any?(&:nil?)

    mode = TravelMode.find_by(name: name)
    next unless mode

    mode.set_approvers!(approvers.map(&:id), mode.watchers.map(&:user_id), mode.is_train? && coo ? [ coo.id ] : [])
  end

  if coo
    TravelMode.where(is_train: true).find_each do |mode|
      mode.set_approvers!(mode.approver_chain.map(&:user_id), mode.watchers.map(&:user_id), [ coo.id ])
    end
  end

  # Per-km rates as on the live form (data-charges). PD Finance changes them from the Rates screen.
  { "Two Wheeler" => 4.25, "Four Wheeler" => 10.00 }.each do |name, rate|
    mode = TravelMode.find_by!(name: name)
    next if mode.mileage_rates.exists?
    mode.mileage_rates.create!(rate_per_km: rate, effective_from: Date.new(2020, 4, 1), created_by: fin, remark: "Rate as on live ESS")
  end

  # City master with DA rate (live ESS: Other 300, small towns 550, state capitals 600, metros 1000)
  require "csv"
  CSV.foreach(Rails.root.join("db/data/cities.csv"), headers: true) do |row|
    City.find_or_initialize_by(name: row["name"]).tap { |c| c.da_rate = row["da_rate"]; c.save! }
  end

  # Finance projects: PD Finance adds them in Masters (their names are also blocked from free-text descriptions)

  ClaimCutoffRule.find_or_create_by!(user_id: nil) do |r|
    r.cutoff_day = ClaimCutoffRule::DEFAULT_DAY
    r.updated_by = hr
    r.remark = "Default: next month opens after the 5th"
  end
end

puts "Seeded: #{User.count} users, #{TravelMode.count} travel modes, #{City.count} cities" unless Rails.env.test?
