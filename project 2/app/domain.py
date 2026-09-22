def validate_order(data):
    if not isinstance(data, dict):
        raise ValueError("Expected an object")
    item = data.get("item")
    quantity = data.get("quantity")
    price = data.get("unit_price_cents")
    if not isinstance(item, str) or not 1 <= len(item.strip()) <= 100:
        raise ValueError("item must contain 1-100 characters")
    if type(quantity) is not int or not 1 <= quantity <= 1000:
        raise ValueError("quantity must be an integer between 1 and 1000")
    if type(price) is not int or not 1 <= price <= 1000000:
        raise ValueError("unit_price_cents must be an integer between 1 and 1000000")
    return item.strip(), quantity, price
