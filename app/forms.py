from flask.ext.wtf import Form
from wtforms import StringField, BooleanField, PasswordField
from wtforms.validators import DataRequired, EqualTo, MacAddress
from app.models import User, Robot

class LoginForm(Form):
	nickname=StringField('nickname', validators=[DataRequired()])
	password=PasswordField('password', validators=[DataRequired()])
	remember_me=BooleanField('remember_me', default=False)

class RegistrationForm(Form):
	firstname=StringField('firstname', validators=[DataRequired()])
	lastname=StringField('lastname', validators=[DataRequired()])
	nickname=StringField('nickname', validators=[DataRequired()])
	robot_mac=StringField('robot_mac', validators=[DataRequired(),MacAddress()])
	robot_name=StringField('robot_name', validators=[DataRequired()])
	password=PasswordField('new_password', validators=[DataRequired(),EqualTo('confirm', message='Password must match')])
	confirm=PasswordField('repeat_password')

	def __init__(self, *args, **kwargs):
		Form.__init__(self, *args, **kwargs)

	def validate(self):
		if not Form.validate(self):
			return False

		errorcheck = False
		onepass = False
		while not checking and not errorcheck:
			user = User.query.filter_by(nickname=self.nickname.data).first()
			if user != None:
				self.nickname.errors.append('This nickname is already in use. Please choose another one.')
				errorcheck = True

			robot = Robot.query.filter_by(alias=self.robot_name.data).first()
			if robot != None:
				self.robot_name.errors.append('This robot name is already in use. Please choose another one.')
				errorcheck = True

			mac = Robot.query.filter_by(macid=self.robot_mac.data).first()
			if mac != None:
				self.robot_mac.errors.append('This robot already has an owner.')
				errorcheck = True
			onepass = True
		
		if errorcheck:
			return False

		return True