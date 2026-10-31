module ClaimsHelper
  # Loaded once per page, shared by every row + the "add row" template (178 cities, few modes)
  def claim_cities      = @claim_cities ||= City.active.ordered.to_a
  # A. Travel: every active mode from the master used for tours / city travel (anything HR adds shows up)
  def city_travel_modes
    @city_travel_modes ||= TravelMode.active.where("for_city_travel OR for_tour_plan").where.not(name: "NA").ordered
                                     .includes(mode_approvers: :user).to_a
  end
  def local_travel_modes = @local_travel_modes ||= TravelMode.local_travel.includes(:mileage_rates).to_a

  def nd(date)  = tag.span(d(date), class: "whitespace-nowrap")
  def ndt(time) = tag.span(dt(time), class: "whitespace-nowrap")

  # Read-only column definitions per section, same order/labels as the live ESS claim form:
  # [title, headers (before AMOUNT/DEDUCTION/TOTAL), ->(line) { cells }]
  def claim_sections
    {
      claim_city_travels: [ "A. Travel (City to City)", [ "Date", "Departure City", "Arrived City", "Mode of Travel", "Bill/ Ticket No.", "Remark" ],
        ->(l) { [ nd(l.travel_date), l.departure_city, l.arrival_city, (l.tatkal? ? "#{l.travel_mode} – Tatkal" : l.travel_mode), l.bill_ticket_no, l.remark ] } ],
      claim_local_travels: [ "B. Local Travel", [ "Date", "Place From", "Place To", "Mode of Travel", "Met. Reading from", "Met. Reading to", "KM", "Purpose/Bill or Ticket Ref", "₹/km" ],
        ->(l) { [ nd(l.travel_date), l.place_from, l.place_to, l.travel_mode, l.meter_from || 0, l.meter_to || 0, l.kilometers, l.purpose, l.rate_per_km || "0.00" ] } ],
      claim_lodgings: [ "C. Lodging Expenses (Stay Expenses)", [ "Date", "Place", "From Date", "To Date", "No of Days", "Lodging Rate", "Remark" ],
        ->(l) { [ nd(l.lodging_date), l.place_label, ndt(l.from_date), ndt(l.to_date), l.no_of_days, l.rate, l.remark ] } ],
      claim_daily_allowances: [ "D. Daily Allowance (DA)", [ "Departure City", "From Date", "Arrival City", "To Date", "No of Days", "DA Rate", "Applicable Rate" ],
        ->(l) { [ l.departure_city, ndt(l.departure_at), l.arrival_label, ndt(l.arrival_at), l.no_of_days, l.da_rate, (l.applicable_percent.zero? ? "Not Applicable" : "#{l.applicable_percent}%") ] } ],
      claim_incidentals: [ "E. Incidental Expenses (Misc/Meeting/Others)", [ "Date", "Particular", "Bill No" ],
        ->(l) { [ nd(l.expense_date), l.particular, l.bill_no ] } ]
    }
  end
end
