"""
Automatic Deduction Service for Circle Saving Goals
Handles periodic automatic transfers from source to destination accounts
based on cycle frequency (daily, weekly, monthly)
"""

from datetime import datetime, timedelta
import os
from dotenv import load_dotenv
from supabase import create_client, Client
import logging

# Load environment variables
load_dotenv()

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Supabase client
SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_KEY = os.getenv('SUPABASE_KEY')

if not SUPABASE_URL or not SUPABASE_KEY:
    logger.error("SUPABASE_URL or SUPABASE_KEY not found in environment variables")
    supabase: Client = None
else:
    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)


class AutoDeductionService:
    """Service to handle automatic deductions for saving goals"""
    
    @staticmethod
    def calculate_amount_per_cycle(goal: dict) -> float:
        """
        Calculate the deduction amount for each cycle
        
        Args:
            goal: SavingGoal record from database
            
        Returns:
            Amount to deduct per cycle
        """
        try:
            target_amount = float(goal['targetAmount'])
            start_date = datetime.strptime(goal['startDate'], '%Y-%m-%d')
            end_date = datetime.strptime(goal['endDate'], '%Y-%m-%d')
            cycle_frequency = goal['cycleFrequency']  # 'daily', 'weekly', 'monthly'
            
            total_days = (end_date - start_date).days
            
            # Calculate number of cycles
            if cycle_frequency == 'daily':
                num_cycles = total_days
            elif cycle_frequency == 'weekly':
                num_cycles = total_days // 7
            elif cycle_frequency == 'monthly':
                # Calculate approximate months
                num_cycles = (end_date.year - start_date.year) * 12 + (end_date.month - start_date.month)
            else:
                logger.warning(f"Unknown cycle frequency: {cycle_frequency}")
                return 0.0
            
            if num_cycles <= 0:
                return 0.0
            
            amount_per_cycle = target_amount / num_cycles
            return round(amount_per_cycle, 2)
        
        except Exception as e:
            logger.error(f"Error calculating amount per cycle: {e}")
            return 0.0
    
    @staticmethod
    def is_deduction_due(goal: dict, last_transaction_date: datetime = None) -> bool:
        """
        Determine if a deduction is due based on cycle frequency
        
        Args:
            goal: SavingGoal record
            last_transaction_date: Date of last auto-deduction (if any)
            
        Returns:
            True if deduction is due, False otherwise
        """
        try:
            cycle_frequency = goal['cycleFrequency']
            now = datetime.now()
            
            if last_transaction_date is None:
                # No previous transaction, check if we're past the start date
                start_date = datetime.strptime(goal['startDate'], '%Y-%m-%d')
                return now >= start_date
            
            # Calculate next deduction date based on cycle frequency
            if cycle_frequency == 'daily':
                next_due_date = last_transaction_date + timedelta(days=1)
            elif cycle_frequency == 'weekly':
                next_due_date = last_transaction_date + timedelta(weeks=1)
            elif cycle_frequency == 'monthly':
                # Add one month
                if last_transaction_date.month == 12:
                    next_due_date = last_transaction_date.replace(year=last_transaction_date.year + 1, month=1)
                else:
                    next_due_date = last_transaction_date.replace(month=last_transaction_date.month + 1)
            else:
                return False
            
            # Check if today >= next due date
            return now >= next_due_date
        
        except Exception as e:
            logger.error(f"Error checking if deduction is due: {e}")
            return False
    
    @staticmethod
    def create_transaction(
        goal_id: str,
        source_account_id: str,
        dest_account_id: str,
        amount: float,
        user_id: str
    ) -> bool:
        """
        Create an automatic transfer transaction
        
        Args:
            goal_id: ID of the saving goal
            source_account_id: Account to deduct from
            dest_account_id: Account to add to
            amount: Amount to transfer
            user_id: User ID
            
        Returns:
            True if successful, False otherwise
        """
        try:
            if not supabase:
                logger.error("Supabase client not initialized")
                return False
            
            # Create transaction record
            transaction_data = {
                'transactionId': f"AUTO_{goal_id}_{datetime.now().strftime('%Y%m%d%H%M%S')}",
                'transactionType': 'Transfer',
                'category': 'Savings',
                'amount': amount,
                'date': datetime.now().strftime('%Y-%m-%d'),
                'time': datetime.now().strftime('%H:%M:%S'),
                'description': f'Auto-deduction for saving goal: {goal_id}',
                'fromAccountId': source_account_id,
                'toAccountId': dest_account_id,
                'status': 'completed',
                'userId': user_id,
                'savingGoalId': goal_id,
                'isAutoDeduction': True,  # Mark as automatic deduction
            }
            
            response = supabase.table('Ledger').insert(transaction_data).execute()
            
            if response.data:
                logger.info(f"Transaction created: {transaction_data['transactionId']}")
                return True
            else:
                logger.error(f"Failed to create transaction for goal {goal_id}")
                return False
        
        except Exception as e:
            logger.error(f"Error creating transaction: {e}")
            return False
    
    @staticmethod
    def update_account_balances(
        source_account_id: str,
        dest_account_id: str,
        amount: float
    ) -> bool:
        """
        Update account balances after deduction
        
        Args:
            source_account_id: Account to deduct from
            dest_account_id: Account to add to
            amount: Amount to transfer
            
        Returns:
            True if successful, False otherwise
        """
        try:
            if not supabase:
                logger.error("Supabase client not initialized")
                return False
            
            # Fetch both accounts
            source_response = supabase.table('Account').select('*').eq('accountId', source_account_id).execute()
            dest_response = supabase.table('Account').select('*').eq('accountId', dest_account_id).execute()
            
            if not source_response.data or not dest_response.data:
                logger.error(f"Could not find accounts: {source_account_id}, {dest_account_id}")
                return False
            
            source_account = source_response.data[0]
            dest_account = dest_response.data[0]
            
            # Calculate new balances
            new_source_balance = float(source_account['balance']) - amount
            new_dest_balance = float(dest_account['balance']) + amount
            
            # Update source account
            supabase.table('Account').update({'balance': new_source_balance}).eq('accountId', source_account_id).execute()
            
            # Update destination account
            supabase.table('Account').update({'balance': new_dest_balance}).eq('accountId', dest_account_id).execute()
            
            logger.info(f"Updated balances for transfer: {source_account_id} -> {dest_account_id}, Amount: {amount}")
            return True
        
        except Exception as e:
            logger.error(f"Error updating account balances: {e}")
            return False
    
    @staticmethod
    def update_goal_current_amount(goal_id: str, amount: float) -> bool:
        """
        Update the currentAmount of a saving goal
        
        Args:
            goal_id: ID of the saving goal
            amount: Amount to add to current amount
            
        Returns:
            True if successful, False otherwise
        """
        try:
            if not supabase:
                logger.error("Supabase client not initialized")
                return False
            
            # Fetch current goal
            response = supabase.table('SavingGoal').select('*').eq('goalId', goal_id).execute()
            
            if not response.data:
                logger.error(f"Could not find goal: {goal_id}")
                return False
            
            goal = response.data[0]
            current_amount = float(goal['currentAmount'])
            new_amount = current_amount + amount
            
            # Update goal
            supabase.table('SavingGoal').update({'currentAmount': new_amount}).eq('goalId', goal_id).execute()
            
            logger.info(f"Updated goal {goal_id}: currentAmount = {new_amount}")
            return True
        
        except Exception as e:
            logger.error(f"Error updating goal current amount: {e}")
            return False
    
    @staticmethod
    def get_last_auto_deduction_date(goal_id: str) -> datetime = None:
        """
        Get the date of the last auto-deduction for a goal
        
        Args:
            goal_id: ID of the saving goal
            
        Returns:
            datetime of last auto-deduction or None
        """
        try:
            if not supabase:
                return None
            
            response = supabase.table('Ledger') \
                .select('date') \
                .eq('savingGoalId', goal_id) \
                .eq('isAutoDeduction', True) \
                .order('date', desc=True) \
                .limit(1) \
                .execute()
            
            if response.data:
                date_str = response.data[0]['date']
                return datetime.strptime(date_str, '%Y-%m-%d')
            
            return None
        
        except Exception as e:
            logger.error(f"Error getting last auto-deduction date: {e}")
            return None
    
    @staticmethod
    def process_auto_deductions():
        """
        Main function to process all due auto-deductions
        Runs periodically (daily, hourly, etc.)
        """
        try:
            logger.info("Starting auto-deduction process...")
            
            if not supabase:
                logger.error("Supabase client not initialized")
                return
            
            # Fetch all active saving goals
            response = supabase.table('SavingGoal') \
                .select('*') \
                .eq('cycleStatus', True) \
                .execute()
            
            if not response.data:
                logger.info("No active saving goals found")
                return
            
            deductions_processed = 0
            
            for goal in response.data:
                try:
                    goal_id = goal['goalId']
                    
                    # Check if goal has ended
                    end_date = datetime.strptime(goal['endDate'], '%Y-%m-%d')
                    if datetime.now() > end_date:
                        logger.info(f"Goal {goal_id} has ended, skipping")
                        continue
                    
                    # Get last deduction date
                    last_deduction_date = AutoDeductionService.get_last_auto_deduction_date(goal_id)
                    
                    # Check if deduction is due
                    if not AutoDeductionService.is_deduction_due(goal, last_deduction_date):
                        continue
                    
                    # Calculate amount per cycle
                    amount = AutoDeductionService.calculate_amount_per_cycle(goal)
                    
                    if amount <= 0:
                        logger.warning(f"Invalid amount for goal {goal_id}: {amount}")
                        continue
                    
                    # Check source account balance
                    source_account_id = goal['sourceAcountId']
                    source_response = supabase.table('Account').select('balance').eq('accountId', source_account_id).execute()
                    
                    if not source_response.data:
                        logger.error(f"Could not find source account: {source_account_id}")
                        continue
                    
                    source_balance = float(source_response.data[0]['balance'])
                    
                    # Only proceed if sufficient balance
                    if source_balance < amount:
                        logger.warning(f"Insufficient balance for goal {goal_id}. Required: {amount}, Available: {source_balance}")
                        continue
                    
                    # Create transaction
                    if not AutoDeductionService.create_transaction(
                        goal_id=goal_id,
                        source_account_id=source_account_id,
                        dest_account_id=goal['destAccountId'],
                        amount=amount,
                        user_id=goal['userId']
                    ):
                        continue
                    
                    # Update account balances
                    if not AutoDeductionService.update_account_balances(
                        source_account_id=source_account_id,
                        dest_account_id=goal['destAccountId'],
                        amount=amount
                    ):
                        logger.error(f"Failed to update balances for goal {goal_id}")
                        continue
                    
                    # Update goal's current amount
                    if not AutoDeductionService.update_goal_current_amount(goal_id, amount):
                        logger.error(f"Failed to update goal amount for {goal_id}")
                        continue
                    
                    deductions_processed += 1
                    logger.info(f"✅ Auto-deduction processed for goal {goal_id}: {amount}")
                
                except Exception as e:
                    logger.error(f"Error processing goal {goal.get('goalId', 'unknown')}: {e}")
                    continue
            
            logger.info(f"✅ Auto-deduction process completed. Processed {deductions_processed} deductions.")
        
        except Exception as e:
            logger.error(f"Error in auto-deduction process: {e}")


def start_auto_deduction_scheduler():
    """
    Start the APScheduler scheduler for auto-deductions
    
    This should be called when the FastAPI app starts
    """
    try:
        from apscheduler.schedulers.background import BackgroundScheduler
        
        scheduler = BackgroundScheduler()
        
        # Schedule auto-deduction to run every hour
        # Adjust the interval as needed:
        # - cron(minute=0) - every hour
        # - cron(hour=0) - once daily at midnight
        # - interval(minutes=60) - every 60 minutes
        scheduler.add_job(
            func=AutoDeductionService.process_auto_deductions,
            trigger="interval",
            minutes=60,  # Run every hour
            id='auto_deduction_job',
            name='Process auto-deductions for saving goals',
            replace_existing=True,
        )
        
        scheduler.start()
        logger.info("✅ Auto-deduction scheduler started (runs every hour)")
        
        return scheduler
    
    except Exception as e:
        logger.error(f"Error starting auto-deduction scheduler: {e}")
        return None
