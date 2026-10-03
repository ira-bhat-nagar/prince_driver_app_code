const Ride = require('../models/ride.model');
const Driver = require('../models/driver.model');
const walletController = require('./wallet.controller');

const rideOfferMaxAgeMs = 10 * 60 * 1000;

function emitRide(req, event, ride) {
  const io = req.app.locals.io;
  if (!io || !ride) return;
  const payload = ride.toSafeObject();
  io.to(`ride:${payload.rideId}`).emit(event, payload);
  if (payload.driverId) io.to(`driver:${payload.driverId}`).emit(event, payload);
}

// Helper to generate unique ride ID
function generateRideId() {
  const rand = Math.floor(100000 + Math.random() * 900000);
  return `GR-${rand}`;
}

/**
 * GET /api/rides/available
 * Returns active pending ride offer for online drivers.
 * If none exists, creates a fresh incoming ride offer in MongoDB Atlas so driver has a real request.
 */
exports.getAvailableRide = async (req, res) => {
  try {
    const driverId = req.driver ? req.driver._id : null;

    // Check if driver is offline
    if (driverId) {
      const driver = await Driver.findById(driverId);
      if (driver && driver.status === 'offline') {
        return res.status(200).json({
          success: true,
          message: 'Driver is offline',
          data: null,
        });
      }

      // If driver already has an active trip, return it
      const activeTrip = await Ride.findOne({
        driverId,
        status: { $in: ['accepted', 'arrived', 'in_progress'] },
      }).sort({ updatedAt: -1 });

      if (activeTrip) {
        return res.status(200).json({
          success: true,
          message: 'Active trip in progress',
          data: activeTrip.toSafeObject(),
          isActive: true,
        });
      }
    }

    let availableRide = null;
    if (driverId) {
      const requestSince = new Date(Date.now() - rideOfferMaxAgeMs);
      availableRide = await Ride.findOne({
        status: 'requested',
        driverId: null,
        offeredToDriverId: driverId,
        requestedAt: { $gte: requestSince },
      }).sort({ createdAt: -1 });

      // Claim a real customer request atomically for a single online driver.
      // This lets the driver's short-poll fallback receive requests even if
      // its Socket.IO connection was temporarily unavailable.
      if (!availableRide) {
        availableRide = await Ride.findOneAndUpdate(
          {
            status: 'requested',
            driverId: null,
            offeredToDriverId: null,
            requestedAt: { $gte: requestSince },
          },
          { $set: { offeredToDriverId: driverId } },
          { new: true, sort: { createdAt: 1 } }
        );
      }
    }

    return res.status(200).json({
      success: true,
      message: availableRide ? 'Incoming ride request found' : 'No ride requests available',
      data: availableRide ? availableRide.toSafeObject() : null,
    });
  } catch (err) {
    console.error('getAvailableRide error:', err);
    return res.status(500).json({
      success: false,
      message: 'Server error retrieving available ride',
      error: err.message,
    });
  }
};

/**
 * POST /api/rides/:rideId/accept
 * Driver accepts the ride. Associates ride with authenticated driver and sets status to 'accepted'.
 */
exports.acceptRide = async (req, res) => {
  try {
    const { rideId } = req.params;
    const driverId = req.driver._id;

    // --- WALLET BALANCE CHECK ---
    // Before accepting, verify driver has minimum required balance.
    // This is enforced server-side and cannot be bypassed by the app.
    const walletCheck = await walletController.checkWalletBalance(driverId);
    if (!walletCheck.allowed) {
      return res.status(402).json({
        success: false,
        code: walletCheck.reason,
        message:
          walletCheck.reason === 'LOW_WALLET_BALANCE'
            ? 'Please recharge your wallet to accept rides.'
            : 'Your wallet is blocked. Please contact support.',
        walletBalance: walletCheck.wallet ? walletCheck.wallet.balance : 0,
        minimumRequiredBalance: walletCheck.config
          ? walletCheck.config.minimumWalletBalance
          : 100,
        wallet: walletCheck.wallet || null,
      });
    }

    // Atomically claim an unassigned request. This prevents two drivers (or a
    // double tap) from racing a read-then-save update.
    const identifiers = [{ rideId }];
    if (/^[0-9a-fA-F]{24}$/.test(rideId)) identifiers.push({ _id: rideId });
    let ride = await Ride.findOneAndUpdate(
      {
        $and: [
          { $or: identifiers },
          { status: 'requested' },
          { driverId: null },
          {
            $or: [
              { offeredToDriverId: driverId },
              { offeredToDriverId: null },
            ],
          },
        ],
      },
      { $set: { driverId, status: 'accepted', acceptedAt: new Date() } },
      { new: true, runValidators: true }
    );

    if (!ride) {
      const existing = await Ride.findOne({ $or: identifiers });
      if (!existing) {
        return res.status(404).json({ success: false, message: 'Ride request not found' });
      }
      // A retry from the driver that already won the claim is a successful,
      // idempotent accept, not a failed ride action.
      if (existing.status === 'accepted' && String(existing.driverId) === String(driverId)) {
        return res.status(200).json({
          success: true,
          message: 'Ride already accepted successfully',
          data: existing.toSafeObject(),
        });
      }
      return res.status(409).json({
        success: false,
        message: 'This ride has already been accepted by another driver or is no longer available',
      });
    }
    emitRide(req, 'ride:status', ride);

    // Mark driver status as busy/online
    await Driver.findByIdAndUpdate(driverId, { status: 'online' });

    return res.status(200).json({
      success: true,
      message: 'Ride accepted successfully',
      data: ride.toSafeObject(),
      wallet: walletCheck.wallet || null,
    });
  } catch (err) {
    console.error('acceptRide error:', err);
    return res.status(500).json({
      success: false,
      message: 'Server error accepting ride',
      error: err.message,
    });
  }
};

/**
 * POST /api/rides/:rideId/reject
 * Driver rejects the ride. Marks status 'cancelled' with cancellation details.
 */
exports.rejectRide = async (req, res) => {
  try {
    const { rideId } = req.params;
    const driverId = req.driver._id;
    const reason = req.body.reason || 'Driver rejected request';

    const query = { $or: [{ rideId }, { _id: rideId.match(/^[0-9a-fA-F]{24}$/) ? rideId : null }] };
    let ride = await Ride.findOne(query);

    if (!ride) {
      return res.status(404).json({
        success: false,
        message: 'Ride request not found',
      });
    }

    ride.driverId = driverId;
    ride.status = 'cancelled';
    ride.cancelledAt = new Date();
    ride.cancelledBy = 'driver';
    ride.cancellationReason = reason;
    await ride.save();
    emitRide(req, 'ride:status', ride);

    return res.status(200).json({
      success: true,
      message: 'Ride rejected and recorded in cancelled history',
      data: ride.toSafeObject(),
    });
  } catch (err) {
    console.error('rejectRide error:', err);
    return res.status(500).json({
      success: false,
      message: 'Server error rejecting ride',
      error: err.message,
    });
  }
};

/**
 * POST /api/rides/:rideId/arrived
 * Driver marks arrival at passenger pickup location.
 */
exports.markArrived = async (req, res) => {
  try {
    const { rideId } = req.params;
    const query = { $or: [{ rideId }, { _id: rideId.match(/^[0-9a-fA-F]{24}$/) ? rideId : null }] };
    const ride = await Ride.findOne(query);

    if (!ride) {
      return res.status(404).json({ success: false, message: 'Ride not found' });
    }

    ride.status = 'arrived';
    ride.arrivedAt = new Date();
    await ride.save();
    emitRide(req, 'ride:status', ride);

    return res.status(200).json({
      success: true,
      message: 'Driver arrived at pickup location',
      data: ride.toSafeObject(),
    });
  } catch (err) {
    console.error('markArrived error:', err);
    return res.status(500).json({
      success: false,
      message: 'Server error marking arrival',
      error: err.message,
    });
  }
};

/**
 * POST /api/rides/:rideId/start
 * Driver starts the trip. Verifies 4-digit passenger OTP.
 */
exports.startTrip = async (req, res) => {
  try {
    const { rideId } = req.params;
    const { otp } = req.body;

    const query = { $or: [{ rideId }, { _id: rideId.match(/^[0-9a-fA-F]{24}$/) ? rideId : null }] };
    const ride = await Ride.findOne(query);

    if (!ride) {
      return res.status(404).json({ success: false, message: 'Ride not found' });
    }

    // Verify OTP if provided
    if (otp && ride.otp && otp.trim() !== ride.otp.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Invalid OTP entered. Please ask the passenger for the correct 4-digit code.',
      });
    }

    ride.status = 'in_progress';
    ride.startedAt = new Date();
    await ride.save();
    emitRide(req, 'ride:status', ride);

    return res.status(200).json({
      success: true,
      message: 'Trip started successfully',
      data: ride.toSafeObject(),
    });
  } catch (err) {
    console.error('startTrip error:', err);
    return res.status(500).json({
      success: false,
      message: 'Server error starting trip',
      error: err.message,
    });
  }
};

/**
 * POST /api/rides/:rideId/complete
 * Driver completes the trip. Calculates/stores fare, marks status 'completed'.
 */
exports.completeTrip = async (req, res) => {
  try {
    const { rideId } = req.params;
    const driverId = req.driver._id;
    const query = { $or: [{ rideId }, { _id: rideId.match(/^[0-9a-fA-F]{24}$/) ? rideId : null }] };
    const ride = await Ride.findOne(query);

    if (!ride) {
      return res.status(404).json({ success: false, message: 'Ride not found' });
    }

    // Mark ride as completed first
    ride.status = 'completed';
    ride.completedAt = new Date();
    ride.fare.isPaid = true;
    await ride.save();
    emitRide(req, 'ride:status', ride);

    // --- WALLET COMPANY CHARGE DEDUCTION ---
    // Process company charge atomically (idempotent — safe to retry).
    // Only for CASH rides: driver collected cash from passenger, so we
    // recover the company's share from their wallet.
    // For ONLINE rides: payment gateway already handles the split.
    const rideFare = ride.fare.total || 0;
    const paymentMethod = ride.fare.paymentMethod || 'CASH';
    const isCashRide = paymentMethod.toUpperCase().includes('CASH');

    let walletResult = null;
    if (rideFare > 0 && isCashRide) {
      try {
        walletResult = await walletController.processCompanyCharge(
          driverId,
          ride.rideId,
          rideFare,
          paymentMethod
        );
        if (!walletResult.success) {
          console.error(`[Wallet] Company charge failed for ride ${ride.rideId}:`, walletResult.message);
          // Do NOT block trip completion — log and continue
          // The admin can manually reconcile insufficient wallet cases
        }
      } catch (walletErr) {
        console.error('[Wallet] Unexpected error during company charge:', walletErr);
        // Do NOT fail the trip completion — wallet error is non-blocking
      }
    }

    // Build accounting summary
    const companyCharge = walletResult && walletResult.companyCharge ? walletResult.companyCharge : 0;
    const accounting = {
      fare: rideFare,
      paymentMethod,
      companyCharge,
      driverGrossEarning: rideFare,
      driverNetEarning: parseFloat((rideFare - companyCharge).toFixed(2)),
      walletDeduction: isCashRide ? companyCharge : 0,
      accountingStatus: walletResult && walletResult.success ? 'SETTLED' : 'PENDING',
    };

    return res.status(200).json({
      success: true,
      message: 'Trip completed successfully',
      data: ride.toSafeObject(),
      wallet: walletResult && walletResult.wallet ? walletResult.wallet : null,
      accounting,
    });
  } catch (err) {
    console.error('completeTrip error:', err);
    return res.status(500).json({
      success: false,
      message: 'Server error completing trip',
      error: err.message,
    });
  }
};

/** Persist a driver GPS heartbeat and broadcast it to ride listeners. */
exports.updateLocation = async (req, res) => {
  try {
    const { rideId } = req.params;
    const { lat, lng, accuracy } = req.body;
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      return res.status(400).json({ success: false, message: 'lat and lng must be numbers' });
    }
    const ride = await Ride.findOne({ rideId, driverId: req.driver._id });
    if (!ride) return res.status(404).json({ success: false, message: 'Active ride not found' });
    ride.driverLocation = { lat, lng, accuracy: Number.isFinite(accuracy) ? accuracy : null, updatedAt: new Date() };
    await ride.save();
    emitRide(req, 'ride:location', ride);
    return res.json({ success: true, data: ride.toSafeObject() });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Unable to update location', error: err.message });
  }
};

/**
 * GET /api/rides/active
 * Returns current active trip for the authenticated driver.
 */
exports.getActiveRide = async (req, res) => {
  try {
    const driverId = req.driver._id;
    const ride = await Ride.findOne({
      driverId,
      status: { $in: ['accepted', 'arrived', 'in_progress'] },
    }).sort({ updatedAt: -1 });

    return res.status(200).json({
      success: true,
      data: ride ? ride.toSafeObject() : null,
    });
  } catch (err) {
    console.error('getActiveRide error:', err);
    return res.status(500).json({
      success: false,
      message: 'Server error getting active ride',
      error: err.message,
    });
  }
};

/**
 * GET /api/rides/history
 * Returns ride history for the authenticated driver, strictly separating COMPLETED and CANCELLED.
 */
exports.getHistory = async (req, res) => {
  try {
    const driverId = req.driver._id;

    const completedRides = await Ride.find({
      driverId,
      status: 'completed',
    }).sort({ completedAt: -1, createdAt: -1 });

    const cancelledRides = await Ride.find({
      driverId,
      status: 'cancelled',
    }).sort({ cancelledAt: -1, createdAt: -1 });

    return res.status(200).json({
      success: true,
      data: {
        completed: completedRides.map((r) => r.toSafeObject()),
        cancelled: cancelledRides.map((r) => r.toSafeObject()),
      },
    });
  } catch (err) {
    console.error('getHistory error:', err);
    return res.status(500).json({
      success: false,
      message: 'Server error retrieving ride history',
      error: err.message,
    });
  }
};

/**
 * GET /api/rides/earnings
 * Aggregates earnings and ride count from completed rides for the authenticated driver.
 */
exports.getEarnings = async (req, res) => {
  try {
    const driverId = req.driver._id;

    const completedRides = await Ride.find({
      driverId,
      status: 'completed',
    });

    const totalRides = completedRides.length;
    let totalEarnings = 0;
    let todayEarnings = 0;

    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);

    for (const r of completedRides) {
      const earned = r.fare?.driverEarnings || r.fare?.total || 0;
      totalEarnings += earned;

      if (r.completedAt && new Date(r.completedAt) >= startOfToday) {
        todayEarnings += earned;
      }
    }

    return res.status(200).json({
      success: true,
      data: {
        totalEarnings,
        todayEarnings,
        totalRides,
        completedRidesCount: totalRides,
      },
    });
  } catch (err) {
    console.error('getEarnings error:', err);
    return res.status(500).json({
      success: false,
      message: 'Server error retrieving driver earnings',
      error: err.message,
    });
  }
};
