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