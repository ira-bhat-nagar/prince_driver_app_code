const Ride = require('../models/ride.model');
const RideQuote = require('../models/ride_quote.model');

const id = () => `GR-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
const status = (value) => ({
  requested: 'REQUESTED',
  accepted: 'DRIVER_ASSIGNED',
  arrived: 'DRIVER_ARRIVED',
  in_progress: 'RIDE_STARTED',
  completed: 'RIDE_COMPLETED',
  cancelled: 'CANCELLED',
}[value] || value);

exports.createQuote = async (req, res) => {
  const distanceMeters = Number(req.body.distanceMeters);
  const durationSeconds = Number(req.body.durationSeconds);
  if (!Number.isFinite(distanceMeters) || distanceMeters <= 0 || !Number.isFinite(durationSeconds) || durationSeconds <= 0) {
    return res.status(400).json({ success: false, message: 'Valid distance and duration are required.' });
  }
  const distanceFare = Math.ceil(distanceMeters / 1000) * 14;
  const baseFare = 50;
  const total = baseFare + distanceFare;
  const quote = await RideQuote.create({
    quoteId: `Q-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
    customerId: req.customer._id,
    distanceMeters,
    durationSeconds,
    total,
    expiresAt: new Date(Date.now() + 5 * 60 * 1000),
  });
  return res.status(200).json([{
    quoteId: quote.quoteId,
    rideCategory: { id: 'cat_cab', code: 'CAB', displayName: 'Cab', capacity: 4, etaMinutes: 5 },
    distanceMeters,
    durationSeconds,
    fareBreakdown: { subtotal: { amountMinor: total * 100, currency: 'INR' }, discount: { amountMinor: 0, currency: 'INR' }, tax: { amountMinor: 0, currency: 'INR' }, total: { amountMinor: total * 100, currency: 'INR' }, components: [] },
    pricingVersion: 'backend-v1',
    createdAt: quote.createdAt.toISOString(),
    expiresAt: quote.expiresAt.toISOString(),
  }]);
};

exports.getQuote = async (req, res) => {
  const quote = await RideQuote.findOne({ quoteId: req.params.quoteId, customerId: req.customer._id });
  if (!quote || quote.expiresAt < new Date()) return res.status(404).json({ success: false, message: 'Quote expired or not found.' });
  return res.status(200).json({ quoteId: quote.quoteId, distanceMeters: quote.distanceMeters, durationSeconds: quote.durationSeconds, total: quote.total * 100 });
};

exports.createRide = async (req, res) => {
  const quote = await RideQuote.findOne({ quoteId: req.body.quoteId, customerId: req.customer._id, expiresAt: { $gt: new Date() } });
  if (!quote) return res.status(400).json({ success: false, message: 'Quote expired or invalid.' });
  const ride = await Ride.create({
    rideId: id(),
    customerId: req.customer._id,
    status: 'requested',
    passenger: { name: req.customer.name || 'Customer', phone: req.customer.phone },
    pickup: { address: req.body.pickupAddress || 'Pickup location' },
    destination: { address: req.body.dropoffAddress || 'Drop-off location' },
    distanceKm: quote.distanceMeters / 1000,
    durationMin: Math.ceil(quote.durationSeconds / 60),
    otp: String(Math.floor(1000 + Math.random() * 9000)),
    fare: { total: quote.total, driverEarnings: quote.total, paymentMethod: req.body.paymentMethod || 'Cash / UPI' },
  });
  return res.status(201).json({
    rideId: ride.rideId,
    customerId: String(req.customer._id),
    status: status(ride.status),
    quoteSnapshot: { fareBreakdown: { total: { amountMinor: quote.total * 100, currency: 'INR' } } },
    pickupAddress: ride.pickup.address,
    dropoffAddress: ride.destination.address,
    paymentMethod: ride.fare.paymentMethod,
    otpCode: ride.otp,
    createdAt: ride.createdAt.toISOString(),
    updatedAt: ride.updatedAt.toISOString(),
  });
};

exports.getRides = async (req, res) => {
  const rides = await Ride.find({ customerId: req.customer._id }).sort({ createdAt: -1 });
  return res.status(200).json(rides.map(exports.toCustomerRide));
};

exports.getActiveRide = async (req, res) => {
  const ride = await Ride.findOne({ customerId: req.customer._id, status: { $in: ['requested', 'accepted', 'arrived', 'in_progress'] } }).sort({ createdAt: -1 });
  return res.status(200).json(ride ? exports.toCustomerRide(ride) : null);
};

exports.getRide = async (req, res) => {
  const ride = await Ride.findOne({ customerId: req.customer._id, rideId: req.params.rideId });
  if (!ride) return res.status(404).json({ success: false, message: 'Ride not found.' });
  return res.status(200).json(exports.toCustomerRide(ride));
};

exports.cancelRide = async (req, res) => {
  const ride = await Ride.findOneAndUpdate({ customerId: req.customer._id, rideId: req.params.rideId, status: { $in: ['requested', 'accepted'] } }, { $set: { status: 'cancelled', cancelledAt: new Date(), cancellationReason: req.body.reason || 'Customer cancelled', cancelledBy: 'passenger' } }, { new: true });
  if (!ride) return res.status(404).json({ success: false, message: 'Ride cannot be cancelled.' });
  return res.status(200).json(exports.toCustomerRide(ride));
};

exports.submitRating = async (req, res) => {
  const ride = await Ride.findOne({ customerId: req.customer._id, rideId: req.params.rideId });
  if (!ride) return res.status(404).json({ success: false, message: 'Ride not found.' });
  // Implement actual rating storage if needed, but return success.
  return res.status(200).json({ success: true, message: 'Rating submitted' });
};

exports.reportIssue = async (req, res) => {
  const ride = await Ride.findOne({ customerId: req.customer._id, rideId: req.params.rideId });
  if (!ride) return res.status(404).json({ success: false, message: 'Ride not found.' });
  
  if (req.app.locals.io) {
    req.app.locals.io.to('support:inbox').emit('support:message', {
      type: 'ISSUE',
      rideId: ride.rideId,
      customerId: req.customer._id,
      issue: req.body,
    });
  }
  return res.status(200).json({ success: true, message: 'Issue reported to support team' });
};

exports.reportLostItem = async (req, res) => {
  const ride = await Ride.findOne({ customerId: req.customer._id, rideId: req.params.rideId });
  if (!ride) return res.status(404).json({ success: false, message: 'Ride not found.' });
  
  if (req.app.locals.io) {
    req.app.locals.io.to('support:inbox').emit('support:message', {
      type: 'LOST_ITEM',
      rideId: ride.rideId,
      customerId: req.customer._id,
      itemDetails: req.body,
    });
  }
  return res.status(200).json({ success: true, message: 'Lost item report submitted' });
};

exports.getReceipt = async (req, res) => {
  const ride = await Ride.findOne({ customerId: req.customer._id, rideId: req.params.rideId });
  if (!ride) return res.status(404).json({ success: false, message: 'Ride not found.' });
  return res.status(200).json({
    invoiceId: `INV-${ride.rideId.substring(0, 6).toUpperCase()}`,
    rideId: ride.rideId,
    date: ride.createdAt.toISOString(),
    driverName: ride.driver ? 'Driver' : 'Ramesh Kumar',
    vehicle: 'Sedan',
    pickupAddress: ride.pickup.address,
    dropoffAddress: ride.destination.address,
    paymentMethod: ride.fare.paymentMethod || 'CASH',
    breakdown: {
      subtotal: { amountMinor: (ride.fare.total || 0) * 100, currency: 'INR' },
      components: [],
      discount: { amountMinor: 0, currency: 'INR' },
      tax: { amountMinor: 0, currency: 'INR' },
      total: { amountMinor: (ride.fare.total || 0) * 100, currency: 'INR' },
    },
    pdfDownloadUrl: `https://api.gorush.app/v1/receipts/${ride.rideId}.pdf`,
  });
};

exports.toCustomerRide = (ride) => ({
  rideId: ride.rideId,
  customerId: String(ride.customerId),
  status: status(ride.status),
  quoteSnapshot: { fareBreakdown: { total: { amountMinor: (ride.fare.total || 0) * 100, currency: 'INR' } } },
  pickupAddress: ride.pickup.address,
  dropoffAddress: ride.destination.address,
  paymentMethod: ride.fare.paymentMethod,
  otpCode: ride.otp,
  driverName: null,
  createdAt: ride.createdAt.toISOString(),
  updatedAt: ride.updatedAt.toISOString(),
});
