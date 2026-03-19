/**
 * Reduces an error object to a human-readable message.
 * Handles Aura-enabled Apex errors, page errors, and generic errors.
 * @param {Object} error - The error object from a failed operation
 * @returns {string} A human-readable error message
 */
export function reduceError(error) {
    if (!error) {
        return 'Unknown error';
    }
    if (Array.isArray(error.body)) {
        return error.body.map((entry) => entry.message).join(', ');
    }
    if (error.body && error.body.message) {
        return error.body.message;
    }
    return error.message || 'Unknown error';
}
