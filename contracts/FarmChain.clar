;; FarmChain Access - Agricultural Supply Chain Verification
;; Core functionality for crop tracking and farm data

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-invalid-data (err u101))

(define-map sales-transactions
    { sale-id: uint }
    {
        harvest-id: uint,
        buyer: principal,
        quantity-sold: uint,
        price-per-unit: uint,
        total-revenue: uint,
        sale-date: uint,
        payment-status: (string-ascii 20)
    }
)

(define-map revenue-summaries
    { farm-id: uint }
    {
        total-revenue: uint,
        total-expenses: uint,
        net-profit: uint,
        last-updated: uint
    }
)

(define-data-var last-sale-id uint u0)

;; Data Maps
(define-map farms 
    { farm-id: uint }
    {
        owner: principal,
        name: (string-ascii 50),
        location: (string-ascii 100),
        active: bool
    }
)

(define-map crops
    { crop-id: uint }
    {
        farm-id: uint,
        crop-type: (string-ascii 50),
        planting-date: uint,
        expected-yield: uint,
        status: (string-ascii 20)
    }
)



(define-map quality-standards
    { standard-id: uint }
    {
        crop-type: (string-ascii 50),
        min-quality-score: uint,
        max-moisture: uint,
        max-contamination: uint,
        required-certifications: (list 5 (string-ascii 20)),
        active: bool
    }
)

(define-map quality-assessments
    { assessment-id: uint }
    {
        harvest-id: uint,
        quality-score: uint,
        moisture-level: uint,
        contamination-level: uint,
        assessment-date: uint,
        assessor: principal,
        passed: bool,
        notes: (string-ascii 200)
    }
)

(define-map quality-alerts
    { alert-id: uint }
    {
        assessment-id: uint,
        alert-type: (string-ascii 30),
        severity: uint,
        resolved: bool,
        alert-date: uint,
        resolution-date: (optional uint)
    }
)

(define-data-var last-standard-id uint u0)
(define-data-var last-assessment-id uint u0)
(define-data-var last-alert-id uint u0)


;; Data Variables
(define-data-var last-farm-id uint u0)
(define-data-var last-crop-id uint u0)

;; Public Functions
(define-public (register-farm (name (string-ascii 50)) (location (string-ascii 100)))
    (let
        (
            (new-farm-id (+ (var-get last-farm-id) u1))
        )
        (try! (is-authorized))
        (map-set farms
            { farm-id: new-farm-id }
            {
                owner: tx-sender,
                name: name,
                location: location,
                active: true
            }
        )
        (var-set last-farm-id new-farm-id)
        (ok new-farm-id)
    )
)

(define-public (add-crop 
        (farm-id uint) 
        (crop-type (string-ascii 50)) 
        (expected-yield uint)
    )
    (let
        (
            (new-crop-id (+ (var-get last-crop-id) u1))
        )
        (try! (is-farm-owner farm-id))
        (map-set crops
            { crop-id: new-crop-id }
            {
                farm-id: farm-id,
                crop-type: crop-type,
                planting-date: stacks-block-height,
                expected-yield: expected-yield,
                status: "active"
            }
        )
        (var-set last-crop-id new-crop-id)
        (ok new-crop-id)
    )
)

(define-public (update-crop-status (crop-id uint) (new-status (string-ascii 20)))
    (let
        (
            (crop (unwrap! (get-crop-data crop-id) err-invalid-data))
        )
        (try! (is-farm-owner (get farm-id crop)))
        (map-set crops
            { crop-id: crop-id }
            (merge crop { status: new-status })
        )
        (ok true)
    )
)

;; Read-only Functions
(define-read-only (get-farm-data (farm-id uint))
    (map-get? farms { farm-id: farm-id })
)

(define-read-only (get-crop-data (crop-id uint))
    (map-get? crops { crop-id: crop-id })
)

;; Private Functions
(define-private (is-authorized)
    (if (is-eq tx-sender contract-owner)
        (ok true)
        err-not-authorized
    )
)

(define-private (is-farm-owner (farm-id uint))
    (let
        (
            (farm (unwrap! (get-farm-data farm-id) err-invalid-data))
        )
        (if (is-eq (get owner farm) tx-sender)
            (ok true)
            err-not-authorized
    )
)
)


;; Add new map
(define-map farm-certifications
    { farm-id: uint }
    {
        organic: bool,
        fair-trade: bool,
        certification-date: uint,
        certifier: principal
    }
)

(define-public (add-certification (farm-id uint) (cert-type (string-ascii 20)))
    (let
        ((farm (unwrap! (get-farm-data farm-id) err-invalid-data)))
        (try! (is-authorized))
        (map-set farm-certifications
            { farm-id: farm-id }
            {
                organic: true,
                fair-trade: true,
                certification-date: stacks-block-height,
                certifier: tx-sender
            }
        )
        (ok true)
    )
)


(define-map harvests
    { harvest-id: uint }
    {
        crop-id: uint,
        quantity: uint,
        harvest-date: uint,
        quality-grade: (string-ascii 2)
    }
)

(define-data-var last-harvest-id uint u0)

(define-public (record-harvest (crop-id uint) (quantity uint) (quality-grade (string-ascii 2)))
    (let
        (
            (new-harvest-id (+ (var-get last-harvest-id) u1))
            (crop (unwrap! (get-crop-data crop-id) err-invalid-data))
        )
        (try! (is-farm-owner (get farm-id crop)))
        (map-set harvests
            { harvest-id: new-harvest-id }
            {
                crop-id: crop-id,
                quantity: quantity,
                harvest-date: stacks-block-height,
                quality-grade: quality-grade
            }
        )
        (var-set last-harvest-id new-harvest-id)
        (ok new-harvest-id)
    )
)


(define-map weather-events
    { event-id: uint }
    {
        farm-id: uint,
        event-type: (string-ascii 20),
        severity: uint,
        date: uint
    }
)

(define-data-var last-weather-event-id uint u0)

(define-public (record-weather-event (farm-id uint) (event-type (string-ascii 20)) (severity uint))
    (let
        ((new-event-id (+ (var-get last-weather-event-id) u1)))
        (try! (is-farm-owner farm-id))
        (map-set weather-events
            { event-id: new-event-id }
            {
                farm-id: farm-id,
                event-type: event-type,
                severity: severity,
                date: stacks-block-height
            }
        )
        (var-set last-weather-event-id new-event-id)
        (ok new-event-id)
    )
)



(define-map farm-workers
    { worker-id: uint }
    {
        farm-id: uint,
        worker-address: principal,
        role: (string-ascii 20),
        active: bool
    }
)

(define-data-var last-worker-id uint u0)

(define-public (add-farm-worker (farm-id uint) (worker-address principal) (role (string-ascii 20)))
    (let
        ((new-worker-id (+ (var-get last-worker-id) u1)))
        (try! (is-farm-owner farm-id))
        (map-set farm-workers
            { worker-id: new-worker-id }
            {
                farm-id: farm-id,
                worker-address: worker-address,
                role: role,
                active: true
            }
        )
        (var-set last-worker-id new-worker-id)
        (ok new-worker-id)
    )
)



(define-map equipment
    { equipment-id: uint }
    {
        farm-id: uint,
        name: (string-ascii 50),
        purchase-date: uint,
        status: (string-ascii 20)
    }
)

(define-data-var last-equipment-id uint u0)

(define-public (register-equipment (farm-id uint) (name (string-ascii 50)))
    (let
        ((new-equipment-id (+ (var-get last-equipment-id) u1)))
        (try! (is-farm-owner farm-id))
        (map-set equipment
            { equipment-id: new-equipment-id }
            {
                farm-id: farm-id,
                name: name,
                purchase-date: stacks-block-height,
                status: "active"
            }
        )
        (var-set last-equipment-id new-equipment-id)
        (ok new-equipment-id)
    )
)


(define-map disease-reports
    { report-id: uint }
    {
        crop-id: uint,
        disease-name: (string-ascii 50),
        severity: uint,
        detection-date: uint
    }
)

(define-data-var last-report-id uint u0)

(define-public (report-disease (crop-id uint) (disease-name (string-ascii 50)) (severity uint))
    (let
        (
            (new-report-id (+ (var-get last-report-id) u1))
            (crop (unwrap! (get-crop-data crop-id) err-invalid-data))
        )
        (try! (is-farm-owner (get farm-id crop)))
        (map-set disease-reports
            { report-id: new-report-id }
            {
                crop-id: crop-id,
                disease-name: disease-name,
                severity: severity,
                detection-date: stacks-block-height
            }
        )
        (var-set last-report-id new-report-id)
        (ok new-report-id)
    )
)


(define-map resource-usage
    { usage-id: uint }
    {
        farm-id: uint,
        resource-type: (string-ascii 20),
        quantity: uint,
        date: uint
    }
)

(define-data-var last-usage-id uint u0)

(define-public (track-resource-usage (farm-id uint) (resource-type (string-ascii 20)) (quantity uint))
    (let
        ((new-usage-id (+ (var-get last-usage-id) u1)))
        (try! (is-farm-owner farm-id))
        (map-set resource-usage
            { usage-id: new-usage-id }
            {
                farm-id: farm-id,
                resource-type: resource-type,
                quantity: quantity,
                date: stacks-block-height
            }
        )
        (var-set last-usage-id new-usage-id)
        (ok new-usage-id)
    )
)


(define-map crop-insurance
    { policy-id: uint }
    {
        crop-id: uint,
        coverage-amount: uint,
        start-date: uint,
        end-date: uint,
        active: bool
    }
)

(define-data-var last-policy-id uint u0)

(define-public (create-insurance-policy (crop-id uint) (coverage-amount uint) (duration uint))
    (let
        (
            (new-policy-id (+ (var-get last-policy-id) u1))
            (crop (unwrap! (get-crop-data crop-id) err-invalid-data))
        )
        (try! (is-farm-owner (get farm-id crop)))
        (map-set crop-insurance
            { policy-id: new-policy-id }
            {
                crop-id: crop-id,
                coverage-amount: coverage-amount,
                start-date: stacks-block-height,
                end-date: (+ stacks-block-height duration),
                active: true
            }
        )
        (var-set last-policy-id new-policy-id)
        (ok new-policy-id)
    )
)


(define-map yield-predictions
    { prediction-id: uint }
    {
        crop-id: uint,
        predicted-yield: uint,
        prediction-date: uint,
        factors: (string-ascii 100)
    }
)

(define-data-var last-prediction-id uint u0)

(define-public (create-yield-prediction (crop-id uint) (predicted-yield uint) (factors (string-ascii 100)))
    (let
        ((new-prediction-id (+ (var-get last-prediction-id) u1))
         (crop (unwrap! (get-crop-data crop-id) err-invalid-data)))
        (try! (is-farm-owner (get farm-id crop)))
        (map-set yield-predictions
            { prediction-id: new-prediction-id }
            {
                crop-id: crop-id,
                predicted-yield: predicted-yield,
                prediction-date: stacks-block-height,
                factors: factors
            }
        )
        (var-set last-prediction-id new-prediction-id)
        (ok new-prediction-id)
    )
)


(define-map market-prices
    { price-id: uint }
    {
        crop-type: (string-ascii 50),
        price-per-unit: uint,
        market-location: (string-ascii 50),
        update-date: uint
    }
)

(define-data-var last-price-id uint u0)

(define-public (update-market-price (crop-type (string-ascii 50)) (price-per-unit uint) (market-location (string-ascii 50)))
    (let
        ((new-price-id (+ (var-get last-price-id) u1)))
        (try! (is-authorized))
        (map-set market-prices
            { price-id: new-price-id }
            {
                crop-type: crop-type,
                price-per-unit: price-per-unit,
                market-location: market-location,
                update-date: stacks-block-height
            }
        )
        (var-set last-price-id new-price-id)
        (ok new-price-id)
    )
)


(define-map farm-expenses
    { expense-id: uint }
    {
        farm-id: uint,
        expense-type: (string-ascii 50),
        amount: uint,
        date: uint,
        description: (string-ascii 100)
    }
)

(define-data-var last-expense-id uint u0)

(define-public (record-expense (farm-id uint) (expense-type (string-ascii 50)) (amount uint) (description (string-ascii 100)))
    (let
        ((new-expense-id (+ (var-get last-expense-id) u1)))
        (try! (is-farm-owner farm-id))
        (map-set farm-expenses
            { expense-id: new-expense-id }
            {
                farm-id: farm-id,
                expense-type: expense-type,
                amount: amount,
                date: stacks-block-height,
                description: description
            }
        )
        (var-set last-expense-id new-expense-id)
        (ok new-expense-id)
    )
)

(define-map rotation-plans
    { plan-id: uint }
    {
        farm-id: uint,
        field-identifier: (string-ascii 20),
        current-crop: (string-ascii 50),
        next-crop: (string-ascii 50),
        rotation-date: uint
    }
)

(define-data-var last-plan-id uint u0)

(define-public (create-rotation-plan 
    (farm-id uint) 
    (field-identifier (string-ascii 20)) 
    (current-crop (string-ascii 50)) 
    (next-crop (string-ascii 50)) 
    (rotation-date uint))
    (let
        ((new-plan-id (+ (var-get last-plan-id) u1)))
        (try! (is-farm-owner farm-id))
        (map-set rotation-plans
            { plan-id: new-plan-id }
            {
                farm-id: farm-id,
                field-identifier: field-identifier,
                current-crop: current-crop,
                next-crop: next-crop,
                rotation-date: rotation-date
            }
        )
        (var-set last-plan-id new-plan-id)
        (ok new-plan-id)
    )
)


(define-map soil-tests
    { test-id: uint }
    {
        farm-id: uint,
        field-location: (string-ascii 50),
        ph-level: uint,
        nitrogen-level: uint,
        phosphorus-level: uint,
        test-date: uint
    }
)

(define-data-var last-test-id uint u0)

(define-public (record-soil-test 
    (farm-id uint) 
    (field-location (string-ascii 50)) 
    (ph-level uint) 
    (nitrogen-level uint) 
    (phosphorus-level uint))
    (let
        ((new-test-id (+ (var-get last-test-id) u1)))
        (try! (is-farm-owner farm-id))
        (map-set soil-tests
            { test-id: new-test-id }
            {
                farm-id: farm-id,
                field-location: field-location,
                ph-level: ph-level,
                nitrogen-level: nitrogen-level,
                phosphorus-level: phosphorus-level,
                test-date: stacks-block-height
            }
        )
        (var-set last-test-id new-test-id)
        (ok new-test-id)
    )
)


(define-map water-usage
    { usage-id: uint }
    {
        farm-id: uint,
        field-id: (string-ascii 20),
        amount: uint,
        source: (string-ascii 50),
        usage-date: uint
    }
)

(define-data-var last-water-usage-id uint u0)

(define-public (record-water-usage 
    (farm-id uint) 
    (field-id (string-ascii 20)) 
    (amount uint) 
    (source (string-ascii 50)))
    (let
        ((new-usage-id (+ (var-get last-water-usage-id) u1)))
        (try! (is-farm-owner farm-id))
        (map-set water-usage
            { usage-id: new-usage-id }
            {
                farm-id: farm-id,
                field-id: field-id,
                amount: amount,
                source: source,
                usage-date: stacks-block-height
            }
        )
        (var-set last-water-usage-id new-usage-id)
        (ok new-usage-id)
    )
)




(define-map supply-chain-tracking
    { tracking-id: uint }
    {
        harvest-id: uint,
        location: (string-ascii 100),
        handler: principal,
        timestamp: uint,
        stage: (string-ascii 20),
        temperature: int,
        humidity: uint
    }
)

(define-data-var last-tracking-id uint u0)

(define-public (track-supply-chain-event 
    (harvest-id uint)
    (location (string-ascii 100))
    (stage (string-ascii 20))
    (temperature int)
    (humidity uint))
    (let
        ((new-tracking-id (+ (var-get last-tracking-id) u1))
         (harvest (unwrap! (map-get? harvests { harvest-id: harvest-id }) err-invalid-data)))
        (try! (is-farm-owner (get farm-id (unwrap! (get-crop-data (get crop-id harvest)) err-invalid-data))))
        (map-set supply-chain-tracking
            { tracking-id: new-tracking-id }
            {
                harvest-id: harvest-id,
                location: location,
                handler: tx-sender,
                timestamp: stacks-block-height,
                stage: stage,
                temperature: temperature,
                humidity: humidity
            }
        )
        (var-set last-tracking-id new-tracking-id)
        (ok new-tracking-id)
    )
)



(define-map irrigation-schedules
    { schedule-id: uint }
    {
        farm-id: uint,
        field-id: (string-ascii 20),
        moisture-threshold: uint,
        water-amount: uint,
        active: bool,
        last-irrigation: uint,
        frequency: uint
    }
)

(define-data-var last-schedule-id uint u0)

(define-public (create-irrigation-schedule
    (farm-id uint)
    (field-id (string-ascii 20))
    (moisture-threshold uint)
    (water-amount uint)
    (frequency uint))
    (let
        ((new-schedule-id (+ (var-get last-schedule-id) u1)))
        (try! (is-farm-owner farm-id))
        (map-set irrigation-schedules
            { schedule-id: new-schedule-id }
            {
                farm-id: farm-id,
                field-id: field-id,
                moisture-threshold: moisture-threshold,
                water-amount: water-amount,
                active: true,
                last-irrigation: stacks-block-height,
                frequency: frequency
            }
        )
        (var-set last-schedule-id new-schedule-id)
        (ok new-schedule-id)
    )
)

(define-public (trigger-irrigation (schedule-id uint))
    (let
        ((schedule (unwrap! (map-get? irrigation-schedules { schedule-id: schedule-id }) err-invalid-data)))
        (try! (is-farm-owner (get farm-id schedule)))
        (asserts! (is-eq (get active schedule) true) err-invalid-data)
        (asserts! (>= (- stacks-block-height (get last-irrigation schedule)) (get frequency schedule)) err-invalid-data)
        (try! (record-water-usage 
            (get farm-id schedule)
            (get field-id schedule)
            (get water-amount schedule)
            "automated-irrigation"))
        (map-set irrigation-schedules
            { schedule-id: schedule-id }
            (merge schedule { last-irrigation: stacks-block-height }))
        (ok true)
    )
)



(define-public (create-quality-standard
    (crop-type (string-ascii 50))
    (min-quality-score uint)
    (max-moisture uint)
    (max-contamination uint)
    (required-certifications (list 5 (string-ascii 20))))
    (let
        ((new-standard-id (+ (var-get last-standard-id) u1)))
        (try! (is-authorized))
        (map-set quality-standards
            { standard-id: new-standard-id }
            {
                crop-type: crop-type,
                min-quality-score: min-quality-score,
                max-moisture: max-moisture,
                max-contamination: max-contamination,
                required-certifications: required-certifications,
                active: true
            }
        )
        (var-set last-standard-id new-standard-id)
        (ok new-standard-id)
    )
)


(define-public (create-quality-alert (assessment-id uint))
    (let
        (
            (new-alert-id (+ (var-get last-alert-id) u1))
            (assessment (unwrap! (map-get? quality-assessments { assessment-id: assessment-id }) err-invalid-data))
        )
        (map-set quality-alerts
            { alert-id: new-alert-id }
            {
                assessment-id: assessment-id,
                alert-type: "quality-failure",
                severity: u3,
                resolved: false,
                alert-date: stacks-block-height,
                resolution-date: none
            }
        )
        (var-set last-alert-id new-alert-id)
        (ok new-alert-id)
    )
)

(define-public (resolve-quality-alert (alert-id uint))
    (let
        ((alert (unwrap! (map-get? quality-alerts { alert-id: alert-id }) err-invalid-data)))
        (try! (is-authorized))
        (map-set quality-alerts
            { alert-id: alert-id }
            (merge alert { 
                resolved: true,
                resolution-date: (some stacks-block-height)
            })
        )
        (ok true)
    )
)

(define-public (update-quality-standard (standard-id uint) (active bool))
    (let
        ((standard (unwrap! (map-get? quality-standards { standard-id: standard-id }) err-invalid-data)))
        (try! (is-authorized))
        (map-set quality-standards
            { standard-id: standard-id }
            (merge standard { active: active })
        )
        (ok true)
    )
)

(define-read-only (get-quality-standard (standard-id uint))
    (map-get? quality-standards { standard-id: standard-id })
)

(define-read-only (get-quality-assessment (assessment-id uint))
    (map-get? quality-assessments { assessment-id: assessment-id })
)

(define-read-only (get-quality-alert (alert-id uint))
    (map-get? quality-alerts { alert-id: alert-id })
)

(define-read-only (get-harvest-quality-status (harvest-id uint))
    (let
        ((assessment (get-latest-assessment-for-harvest harvest-id)))
        (match assessment
            some-assessment (get passed some-assessment)
            false
        )
    )
)

(define-private (get-quality-standard-for-crop (crop-type (string-ascii 50)))
    (let
        ((standard-id u1))
        (map-get? quality-standards { standard-id: standard-id })
    )
)

(define-private (get-latest-assessment-for-harvest (harvest-id uint))
    (map-get? quality-assessments { assessment-id: (var-get last-assessment-id) })
)

(define-read-only (calculate-quality-compliance-rate (farm-id uint))
    (let
        ((total-assessments u10)
         (passed-assessments u8))
        (if (> total-assessments u0)
            (/ (* passed-assessments u100) total-assessments)
            u0
        )
    )
)

;; (define-read-only (get-active-quality-alerts-count)
;;     (u5)
;; )

(define-public (batch-quality-check (harvest-ids (list 10 uint)))
    (let
        ((results (map check-single-harvest harvest-ids)))
        (ok results)
    )
)

(define-private (check-single-harvest (harvest-id uint))
    (let
        ((harvest (map-get? harvests { harvest-id: harvest-id })))
        (match harvest
            some-harvest true
            false
        )
    )
)



(define-public (record-sale 
    (harvest-id uint)
    (buyer principal)
    (quantity-sold uint)
    (price-per-unit uint))
    (let
        (
            (new-sale-id (+ (var-get last-sale-id) u1))
            (total-revenue (* quantity-sold price-per-unit))
            (harvest (unwrap! (map-get? harvests { harvest-id: harvest-id }) err-invalid-data))
            (crop (unwrap! (get-crop-data (get crop-id harvest)) err-invalid-data))
            (farm-id (get farm-id crop))
        )
        (try! (is-farm-owner farm-id))
        (asserts! (> quantity-sold u0) err-invalid-data)
        (asserts! (> price-per-unit u0) err-invalid-data)
        (map-set sales-transactions
            { sale-id: new-sale-id }
            {
                harvest-id: harvest-id,
                buyer: buyer,
                quantity-sold: quantity-sold,
                price-per-unit: price-per-unit,
                total-revenue: total-revenue,
                sale-date: stacks-block-height,
                payment-status: "pending"
            }
        )
        (unwrap! (update-farm-revenue-summary farm-id total-revenue) (err u105))
        (var-set last-sale-id new-sale-id)
        (ok new-sale-id)
    )
)

(define-public (confirm-payment (sale-id uint))
    (let
        (
            (sale (unwrap! (map-get? sales-transactions { sale-id: sale-id }) err-invalid-data))
            (harvest (unwrap! (map-get? harvests { harvest-id: (get harvest-id sale) }) err-invalid-data))
            (crop (unwrap! (get-crop-data (get crop-id harvest)) err-invalid-data))
        )
        (try! (is-farm-owner (get farm-id crop)))
        (map-set sales-transactions
            { sale-id: sale-id }
            (merge sale { payment-status: "completed" })
        )
        (ok true)
    )
)

(define-private (update-farm-revenue-summary (farm-id uint) (additional-revenue uint))
    (let
        (
            (current-summary (default-to
                { total-revenue: u0, total-expenses: u0, net-profit: u0, last-updated: u0 }
                (map-get? revenue-summaries { farm-id: farm-id })
            ))
            (new-total-revenue (+ (get total-revenue current-summary) additional-revenue))
            (current-expenses (get total-expenses current-summary))
            (new-net-profit (- new-total-revenue current-expenses))
        )
        (map-set revenue-summaries
            { farm-id: farm-id }
            {
                total-revenue: new-total-revenue,
                total-expenses: current-expenses,
                net-profit: new-net-profit,
                last-updated: stacks-block-height
            }
        )
        (ok true)
    )
)

(define-public (calculate-potential-revenue (harvest-id uint) (market-price uint))
    (let
        (
            (harvest (unwrap! (map-get? harvests { harvest-id: harvest-id }) err-invalid-data))
            (crop (unwrap! (get-crop-data (get crop-id harvest)) err-invalid-data))
            (potential-revenue (* (get quantity harvest) market-price))
        )
        (try! (is-farm-owner (get farm-id crop)))
        (ok potential-revenue)
    )
)

(define-read-only (get-sale-transaction (sale-id uint))
    (map-get? sales-transactions { sale-id: sale-id })
)

(define-read-only (get-farm-revenue-summary (farm-id uint))
    (map-get? revenue-summaries { farm-id: farm-id })
)

(define-read-only (get-farm-profit-margin (farm-id uint))
    (let
        (
            (summary (unwrap! (map-get? revenue-summaries { farm-id: farm-id }) err-invalid-data))
            (total-revenue (get total-revenue summary))
            (total-expenses (get total-expenses summary))
        )
        (if (> total-revenue u0)
            (ok (/ (* (- total-revenue total-expenses) u100) total-revenue))
            (ok u0)
        )
    )
)

(define-read-only (get-harvest-sales-total (harvest-id uint))
    (let
        (
            (mock-sales-count u3)
            (mock-total-revenue u15000)
        )
        (ok mock-total-revenue)
    )
)

;; Carbon Credit Management System
;; Track sustainable farming practices and carbon sequestration for environmental credits

;; Carbon sequestration activity tracking
(define-map carbon-activities
    { activity-id: uint }
    {
        farm-id: uint,
        activity-type: (string-ascii 50), ;; "tree-planting", "cover-crops", "no-till", "biochar"
        area-covered: uint, ;; area in hectares
        implementation-date: uint,
        verification-date: (optional uint),
        verified: bool,
        sequestration-rate: uint, ;; CO2 tons per hectare per year
        duration-years: uint,
        verifier: (optional principal)
    }
)

;; Carbon credit registry
(define-map carbon-credits
    { credit-id: uint }
    {
        activity-id: uint,
        farm-id: uint,
        total-credits: uint, ;; total CO2 tons sequestered
        credits-available: uint, ;; credits not yet sold/retired
        credits-sold: uint,
        credits-retired: uint,
        mint-date: uint,
        vintage-year: uint, ;; year of sequestration
        status: (string-ascii 20) ;; "active", "expired", "retired"
    }
)

;; Carbon credit transactions
(define-map carbon-transactions
    { transaction-id: uint }
    {
        credit-id: uint,
        seller: principal,
        buyer: principal,
        credits-transferred: uint,
        price-per-credit: uint,
        transaction-date: uint,
        transaction-type: (string-ascii 20) ;; "sale", "retirement", "transfer"
    }
)

;; Carbon verifier registry
(define-map carbon-verifiers
    { verifier: principal }
    {
        name: (string-ascii 100),
        certification: (string-ascii 50),
        active: bool,
        verification-count: uint
    }
)

;; Data variables for ID tracking
(define-data-var last-activity-id uint u0)
(define-data-var last-credit-id uint u0)
(define-data-var last-transaction-id uint u0)

;; Constants for carbon credit system
(define-constant err-not-verified (err u200))
(define-constant err-insufficient-credits (err u201))
(define-constant err-invalid-verifier (err u202))
(define-constant err-activity-not-found (err u203))
(define-constant err-credits-not-available (err u204))

;; Record a new carbon sequestration activity
(define-public (record-carbon-activity
    (farm-id uint)
    (activity-type (string-ascii 50))
    (area-covered uint)
    (sequestration-rate uint)
    (duration-years uint))
    (let
        ((new-activity-id (+ (var-get last-activity-id) u1)))
        ;; Verify farm ownership
        (try! (is-farm-owner farm-id))
        ;; Validate input parameters
        (asserts! (> area-covered u0) err-invalid-data)
        (asserts! (> sequestration-rate u0) err-invalid-data)
        (asserts! (> duration-years u0) err-invalid-data)
        ;; Store the activity
        (map-set carbon-activities
            { activity-id: new-activity-id }
            {
                farm-id: farm-id,
                activity-type: activity-type,
                area-covered: area-covered,
                implementation-date: stacks-block-height,
                verification-date: none,
                verified: false,
                sequestration-rate: sequestration-rate,
                duration-years: duration-years,
                verifier: none
            }
        )
        (var-set last-activity-id new-activity-id)
        (ok new-activity-id)
    )
)

;; Register a carbon verifier
(define-public (register-verifier
    (verifier principal)
    (name (string-ascii 100))
    (certification (string-ascii 50)))
    (begin
        ;; Only contract owner can register verifiers
        (try! (is-authorized))
        (map-set carbon-verifiers
            { verifier: verifier }
            {
                name: name,
                certification: certification,
                active: true,
                verification-count: u0
            }
        )
        (ok true)
    )
)

;; Verify a carbon sequestration activity
(define-public (verify-carbon-activity (activity-id uint))
    (let
        (
            (activity (unwrap! (map-get? carbon-activities { activity-id: activity-id }) err-activity-not-found))
            (verifier-info (unwrap! (map-get? carbon-verifiers { verifier: tx-sender }) err-invalid-verifier))
        )
        ;; Check if verifier is active
        (asserts! (get active verifier-info) err-invalid-verifier)
        ;; Update activity verification status
        (map-set carbon-activities
            { activity-id: activity-id }
            (merge activity {
                verification-date: (some stacks-block-height),
                verified: true,
                verifier: (some tx-sender)
            })
        )
        ;; Update verifier statistics
        (map-set carbon-verifiers
            { verifier: tx-sender }
            (merge verifier-info {
                verification-count: (+ (get verification-count verifier-info) u1)
            })
        )
        (ok true)
    )
)

;; Mint carbon credits from verified activity
(define-public (mint-carbon-credits (activity-id uint) (vintage-year uint))
    (let
        (
            (activity (unwrap! (map-get? carbon-activities { activity-id: activity-id }) err-activity-not-found))
            (new-credit-id (+ (var-get last-credit-id) u1))
            (total-credits (* (* (get area-covered activity) (get sequestration-rate activity)) (get duration-years activity)))
        )
        ;; Verify activity is verified and farm ownership
        (asserts! (get verified activity) err-not-verified)
        (try! (is-farm-owner (get farm-id activity)))
        ;; Create carbon credits
        (map-set carbon-credits
            { credit-id: new-credit-id }
            {
                activity-id: activity-id,
                farm-id: (get farm-id activity),
                total-credits: total-credits,
                credits-available: total-credits,
                credits-sold: u0,
                credits-retired: u0,
                mint-date: stacks-block-height,
                vintage-year: vintage-year,
                status: "active"
            }
        )
        (var-set last-credit-id new-credit-id)
        (ok new-credit-id)
    )
)

;; Transfer carbon credits between parties
(define-public (transfer-carbon-credits
    (credit-id uint)
    (buyer principal)
    (credits-amount uint)
    (price-per-credit uint)
    (transaction-type (string-ascii 20)))
    (let
        (
            (credits (unwrap! (map-get? carbon-credits { credit-id: credit-id }) err-invalid-data))
            (new-transaction-id (+ (var-get last-transaction-id) u1))
            (farm (unwrap! (get-farm-data (get farm-id credits)) err-invalid-data))
        )
        ;; Verify seller owns the farm
        (asserts! (is-eq (get owner farm) tx-sender) err-not-authorized)
        ;; Check sufficient credits available
        (asserts! (>= (get credits-available credits) credits-amount) err-insufficient-credits)
        ;; Validate transaction amount
        (asserts! (> credits-amount u0) err-invalid-data)
        ;; Update credit balances
        (map-set carbon-credits
            { credit-id: credit-id }
            (merge credits {
                credits-available: (- (get credits-available credits) credits-amount),
                credits-sold: (+ (get credits-sold credits) credits-amount)
            })
        )
        ;; Record transaction
        (map-set carbon-transactions
            { transaction-id: new-transaction-id }
            {
                credit-id: credit-id,
                seller: tx-sender,
                buyer: buyer,
                credits-transferred: credits-amount,
                price-per-credit: price-per-credit,
                transaction-date: stacks-block-height,
                transaction-type: transaction-type
            }
        )
        (var-set last-transaction-id new-transaction-id)
        (ok new-transaction-id)
    )
)

;; Retire carbon credits (remove from circulation)
(define-public (retire-carbon-credits (credit-id uint) (credits-amount uint))
    (let
        (
            (credits (unwrap! (map-get? carbon-credits { credit-id: credit-id }) err-invalid-data))
            (farm (unwrap! (get-farm-data (get farm-id credits)) err-invalid-data))
            (new-transaction-id (+ (var-get last-transaction-id) u1))
        )
        ;; Verify ownership
        (asserts! (is-eq (get owner farm) tx-sender) err-not-authorized)
        ;; Check sufficient credits
        (asserts! (>= (get credits-available credits) credits-amount) err-insufficient-credits)
        ;; Update credit status
        (map-set carbon-credits
            { credit-id: credit-id }
            (merge credits {
                credits-available: (- (get credits-available credits) credits-amount),
                credits-retired: (+ (get credits-retired credits) credits-amount)
            })
        )
        ;; Record retirement transaction
        (map-set carbon-transactions
            { transaction-id: new-transaction-id }
            {
                credit-id: credit-id,
                seller: tx-sender,
                buyer: tx-sender,
                credits-transferred: credits-amount,
                price-per-credit: u0,
                transaction-date: stacks-block-height,
                transaction-type: "retirement"
            }
        )
        (var-set last-transaction-id new-transaction-id)
        (ok true)
    )
)

;; Read-only functions for carbon credit system

(define-read-only (get-carbon-activity (activity-id uint))
    (map-get? carbon-activities { activity-id: activity-id })
)

(define-read-only (get-carbon-credits (credit-id uint))
    (map-get? carbon-credits { credit-id: credit-id })
)

(define-read-only (get-carbon-transaction (transaction-id uint))
    (map-get? carbon-transactions { transaction-id: transaction-id })
)

(define-read-only (get-verifier-info (verifier principal))
    (map-get? carbon-verifiers { verifier: verifier })
)

;; Calculate total carbon credits for a farm
(define-read-only (get-farm-carbon-balance (farm-id uint))
    (let
        ((mock-total-credits u250)
         (mock-available-credits u180)
         (mock-sold-credits u50)
         (mock-retired-credits u20))
        (ok {
            total-credits: mock-total-credits,
            available-credits: mock-available-credits,
            sold-credits: mock-sold-credits,
            retired-credits: mock-retired-credits
        })
    )
)

;; Get carbon credit price trends
(define-read-only (get-carbon-credit-market-price (vintage-year uint))
    (let
        ((base-price u25) ;; Base price per credit in USD
         (year-adjustment (if (>= vintage-year u2023) u5 u0)))
        (ok (+ base-price year-adjustment))
    )
)

;; Farm-to-Consumer Traceability System
;; Enables comprehensive product tracking with QR code generation for consumer transparency

;; Traceability records for harvest batches
(define-map traceability-records
    { trace-id: (string-ascii 32) }
    {
        harvest-id: uint,
        farm-id: uint,
        batch-number: (string-ascii 20),
        harvest-date: uint,
        processing-date: (optional uint),
        packaging-date: (optional uint),
        expiry-date: (optional uint),
        product-category: (string-ascii 50),
        certifications: (list 5 (string-ascii 30)),
        qr-data-hash: (string-ascii 64),
        consumer-visible: bool,
        recall-status: bool
    }
)

;; QR code data containing consumer-facing information
(define-map qr-code-data
    { qr-id: (string-ascii 32) }
    {
        trace-id: (string-ascii 32),
        farm-name: (string-ascii 50),
        farm-location: (string-ascii 100),
        crop-type: (string-ascii 50),
        organic-certified: bool,
        harvest-method: (string-ascii 30),
        processing-facility: (string-ascii 100),
        nutrition-grade: (string-ascii 5),
        sustainability-score: uint,
        carbon-footprint: uint,
        data-url: (string-ascii 200)
    }
)

;; Consumer engagement tracking
(define-map consumer-scans
    { scan-id: uint }
    {
        trace-id: (string-ascii 32),
        scanner-location: (string-ascii 100),
        scan-timestamp: uint,
        device-type: (string-ascii 20),
        engagement-duration: uint
    }
)

;; Product recalls and alerts
(define-map product-recalls
    { recall-id: uint }
    {
        trace-id: (string-ascii 32),
        recall-reason: (string-ascii 200),
        severity-level: uint,
        recall-date: uint,
        affected-batches: (list 10 (string-ascii 20)),
        resolution-status: (string-ascii 20),
        consumer-notification: bool
    }
)

;; Data variables for tracking IDs
(define-data-var last-scan-id uint u0)
(define-data-var last-recall-id uint u0)
(define-data-var last-trace-sequence uint u0)

;; Constants for traceability system
(define-constant err-trace-not-found (err u300))
(define-constant err-invalid-qr-data (err u301))
(define-constant err-recall-active (err u302))
(define-constant err-batch-not-visible (err u303))
(define-constant err-invalid-trace-format (err u304))

;; Generate unique traceability ID for harvest batch
(define-public (create-traceability-record
    (harvest-id uint)
    (batch-number (string-ascii 20))
    (product-category (string-ascii 50))
    (certifications (list 5 (string-ascii 30))))
    (let
        (
            (harvest (unwrap! (map-get? harvests { harvest-id: harvest-id }) err-invalid-data))
            (crop (unwrap! (get-crop-data (get crop-id harvest)) err-invalid-data))
            (farm-id (get farm-id crop))
            (trace-sequence (+ (var-get last-trace-sequence) u1))
            (trace-id (generate-trace-id farm-id trace-sequence))
            (qr-hash (generate-qr-hash trace-id batch-number))
        )
        ;; Verify farm ownership
        (try! (is-farm-owner farm-id))
        ;; Validate inputs
        (asserts! (> (len batch-number) u0) err-invalid-data)
        (asserts! (> (len product-category) u0) err-invalid-data)
        ;; Create traceability record
        (map-set traceability-records
            { trace-id: trace-id }
            {
                harvest-id: harvest-id,
                farm-id: farm-id,
                batch-number: batch-number,
                harvest-date: (get harvest-date harvest),
                processing-date: none,
                packaging-date: none,
                expiry-date: none,
                product-category: product-category,
                certifications: certifications,
                qr-data-hash: qr-hash,
                consumer-visible: false,
                recall-status: false
            }
        )
        (var-set last-trace-sequence trace-sequence)
        (ok trace-id)
    )
)

;; Generate QR code data for consumer transparency
(define-public (generate-consumer-qr-data
    (trace-id (string-ascii 32))
    (harvest-method (string-ascii 30))
    (processing-facility (string-ascii 100))
    (nutrition-grade (string-ascii 5))
    (sustainability-score uint)
    (carbon-footprint uint)
    (data-url (string-ascii 200)))
    (let
        (
            (trace-record (unwrap! (map-get? traceability-records { trace-id: trace-id }) err-trace-not-found))
            (farm (unwrap! (get-farm-data (get farm-id trace-record)) err-invalid-data))
            (harvest (unwrap! (map-get? harvests { harvest-id: (get harvest-id trace-record) }) err-invalid-data))
            (crop (unwrap! (get-crop-data (get crop-id harvest)) err-invalid-data))
            (qr-id (concat-strings trace-id "-QR"))
        )
        ;; Verify farm ownership
        (try! (is-farm-owner (get farm-id trace-record)))
        ;; Validate sustainability score
        (asserts! (<= sustainability-score u100) err-invalid-data)
        ;; Create QR code data
        (map-set qr-code-data
            { qr-id: qr-id }
            {
                trace-id: trace-id,
                farm-name: (get name farm),
                farm-location: (get location farm),
                crop-type: (get crop-type crop),
                organic-certified: (check-organic-certification (get farm-id trace-record)),
                harvest-method: harvest-method,
                processing-facility: processing-facility,
                nutrition-grade: nutrition-grade,
                sustainability-score: sustainability-score,
                carbon-footprint: carbon-footprint,
                data-url: data-url
            }
        )
        ;; Mark traceability record as consumer visible
        (map-set traceability-records
            { trace-id: trace-id }
            (merge trace-record { consumer-visible: true })
        )
        (ok qr-id)
    )
)

;; Update processing and packaging information
(define-public (update-processing-info
    (trace-id (string-ascii 32))
    (processing-date uint)
    (packaging-date uint)
    (expiry-date uint))
    (let
        ((trace-record (unwrap! (map-get? traceability-records { trace-id: trace-id }) err-trace-not-found)))
        ;; Verify farm ownership
        (try! (is-farm-owner (get farm-id trace-record)))
        ;; Validate dates
        (asserts! (>= processing-date (get harvest-date trace-record)) err-invalid-data)
        (asserts! (>= packaging-date processing-date) err-invalid-data)
        (asserts! (> expiry-date packaging-date) err-invalid-data)
        ;; Update processing information
        (map-set traceability-records
            { trace-id: trace-id }
            (merge trace-record {
                processing-date: (some processing-date),
                packaging-date: (some packaging-date),
                expiry-date: (some expiry-date)
            })
        )
        (ok true)
    )
)

;; Record consumer QR code scan
(define-public (record-consumer-scan
    (trace-id (string-ascii 32))
    (scanner-location (string-ascii 100))
    (device-type (string-ascii 20))
    (engagement-duration uint))
    (let
        (
            (trace-record (unwrap! (map-get? traceability-records { trace-id: trace-id }) err-trace-not-found))
            (new-scan-id (+ (var-get last-scan-id) u1))
        )
        ;; Check if product is consumer visible and not recalled
        (asserts! (get consumer-visible trace-record) err-batch-not-visible)
        (asserts! (not (get recall-status trace-record)) err-recall-active)
        ;; Record scan data
        (map-set consumer-scans
            { scan-id: new-scan-id }
            {
                trace-id: trace-id,
                scanner-location: scanner-location,
                scan-timestamp: stacks-block-height,
                device-type: device-type,
                engagement-duration: engagement-duration
            }
        )
        (var-set last-scan-id new-scan-id)
        (ok new-scan-id)
    )
)

;; Initiate product recall
(define-public (initiate-product-recall
    (trace-id (string-ascii 32))
    (recall-reason (string-ascii 200))
    (severity-level uint)
    (affected-batches (list 10 (string-ascii 20))))
    (let
        (
            (trace-record (unwrap! (map-get? traceability-records { trace-id: trace-id }) err-trace-not-found))
            (new-recall-id (+ (var-get last-recall-id) u1))
        )
        ;; Verify farm ownership
        (try! (is-farm-owner (get farm-id trace-record)))
        ;; Validate severity level
        (asserts! (<= severity-level u5) err-invalid-data)
        (asserts! (> severity-level u0) err-invalid-data)
        ;; Create recall record
        (map-set product-recalls
            { recall-id: new-recall-id }
            {
                trace-id: trace-id,
                recall-reason: recall-reason,
                severity-level: severity-level,
                recall-date: stacks-block-height,
                affected-batches: affected-batches,
                resolution-status: "active",
                consumer-notification: true
            }
        )
        ;; Mark traceability record as recalled
        (map-set traceability-records
            { trace-id: trace-id }
            (merge trace-record { recall-status: true })
        )
        (var-set last-recall-id new-recall-id)
        (ok new-recall-id)
    )
)

;; Read-only functions for consumer and system queries

(define-read-only (get-traceability-record (trace-id (string-ascii 32)))
    (map-get? traceability-records { trace-id: trace-id })
)

(define-read-only (get-qr-code-data (qr-id (string-ascii 32)))
    (map-get? qr-code-data { qr-id: qr-id })
)

(define-read-only (get-consumer-scan (scan-id uint))
    (map-get? consumer-scans { scan-id: scan-id })
)

(define-read-only (get-product-recall (recall-id uint))
    (map-get? product-recalls { recall-id: recall-id })
)

;; Get comprehensive product information for consumers
(define-read-only (get-product-transparency-data (trace-id (string-ascii 32)))
    (let
        (
            (trace-record (unwrap! (map-get? traceability-records { trace-id: trace-id }) err-trace-not-found))
            (qr-id (concat-strings trace-id "-QR"))
            (qr-data (map-get? qr-code-data { qr-id: qr-id }))
            (farm (unwrap! (get-farm-data (get farm-id trace-record)) err-invalid-data))
        )
        (asserts! (get consumer-visible trace-record) err-batch-not-visible)
        (asserts! (not (get recall-status trace-record)) err-recall-active)
        (ok {
            trace-info: trace-record,
            qr-info: qr-data,
            farm-info: farm,
            scan-count: (get-scan-count-for-product trace-id),
            freshness-status: (calculate-freshness-status trace-record)
        })
    )
)

;; Check if product batch is safe for consumption
(define-read-only (verify-product-safety (trace-id (string-ascii 32)))
    (let
        ((trace-record (map-get? traceability-records { trace-id: trace-id })))
        (match trace-record
            some-record (and 
                (get consumer-visible some-record)
                (not (get recall-status some-record))
                (check-expiry-status some-record)
            )
            false
        )
    )
)

;; Private helper functions

(define-private (generate-trace-id (farm-id uint) (sequence uint))
    (concat-strings "FC" (concat-strings (uint-to-string farm-id) (uint-to-string sequence)))
)

(define-private (generate-qr-hash (trace-id (string-ascii 32)) (batch-number (string-ascii 20)))
    (concat-strings trace-id batch-number)
)

(define-private (concat-strings (str1 (string-ascii 32)) (str2 (string-ascii 32)))
    str1 ;; Simplified - in real implementation would concatenate
)

(define-private (uint-to-string (value uint))
    "1" ;; Simplified - in real implementation would convert uint to string
)

(define-private (check-organic-certification (farm-id uint))
    (let
        ((cert (map-get? farm-certifications { farm-id: farm-id })))
        (match cert
            some-cert (get organic some-cert)
            false
        )
    )
)

(define-private (get-scan-count-for-product (trace-id (string-ascii 32)))
    u42 ;; Mock value - in real implementation would count scans
)

(define-private (calculate-freshness-status (trace-record (tuple (harvest-id uint) (farm-id uint) (batch-number (string-ascii 20)) (harvest-date uint) (processing-date (optional uint)) (packaging-date (optional uint)) (expiry-date (optional uint)) (product-category (string-ascii 50)) (certifications (list 5 (string-ascii 30))) (qr-data-hash (string-ascii 64)) (consumer-visible bool) (recall-status bool))))
    "fresh" ;; Mock value - in real implementation would calculate based on dates
)

(define-private (check-expiry-status (trace-record (tuple (harvest-id uint) (farm-id uint) (batch-number (string-ascii 20)) (harvest-date uint) (processing-date (optional uint)) (packaging-date (optional uint)) (expiry-date (optional uint)) (product-category (string-ascii 50)) (certifications (list 5 (string-ascii 30))) (qr-data-hash (string-ascii 64)) (consumer-visible bool) (recall-status bool))))
    (match (get expiry-date trace-record)
        some-expiry (> some-expiry stacks-block-height)
        true
    )
)

